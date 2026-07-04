---
type: Postmortem
title: Internal DNS with AdGuard Home
description: How AdGuard Home was deployed on hostNetwork to provide internal DNS resolution for tailnet devices, including three failed attempts and the final architecture.
tags: [dns, adguard, tailscale, networking, kubernetes]
timestamp: 2026-06-26T00:00:00Z
---

# Internal DNS with AdGuard Home

How tailnet devices resolve `*.homelab` domains without touching the host or cluster DNS. See the [DNS architecture overview](/knowledge.md#dns-architecture) for context.

---

## Situation

Self-hosted services (MinIO, ArgoCD, apps) needed DNS resolution from tailnet devices. `/etc/hosts` worked for one machine but didn't scale — phones, laptops, and other devices couldn't resolve `.homelab` domains.

For full context, see the [homelab history](/history.md#phase-4-internal-dns-with-adguard-home-june-25-26).

**Constraints:**
- No public DNS — domains are internal (`*.homelab`)
- Must not interfere with host (`systemd-resolved`) or cluster (`CoreDNS`) DNS
- Must work over Tailscale (devices not on the LAN)
- One k3s node, Traefik handles ingress by hostname

---

## Task

Deploy AdGuard Home in the cluster so tailnet devices can resolve `*.homelab` → Traefik LoadBalancer IP, without breaking existing DNS paths.

---

## Action

### Attempt 1 — ClusterIP only ❌

Deployed AdGuard with a `ClusterIP` service. DNS port 53 was reachable only inside the cluster network (`10.42.x.x`). Tailnet devices couldn't query it.

### Attempt 2 — `hostPort` with TCP-only DNAT ❌

Added `hostPort: 53` to the Deployment. Kubernetes created an iptables DNAT rule redirecting `host:53/TCP` → `pod:53/TCP`.

**Problem:** `hostPort` for UDP didn't work — k3s mapped it to `0/UDP`. DNS clients primarily use UDP. TCP queries worked, UDP queries dropped silently.

Phone could not resolve `.homelab`; laptop sometimes worked via TCP fallback.

### Attempt 3 — `hostNetwork` with web UI port shift ✅

Switched to `hostNetwork: true`. The pod shares the host's network stack — binds `0.0.0.0:53` (TCP+UDP) directly on the host. No DNAT, no port mapping, no UDP gap.

**Conflict discovered:** AdGuard's admin UI was on port 80, which is also Traefik's HTTP entrypoint. With `hostNetwork`, `0.0.0.0:80` would collide.

**Fix:** Changed AdGuard's admin UI to port `8080` (via `AdGuardHome.yaml`). Traefik still owns port 80 for host-based routing. The Ingress routes `adguard.homelab:80` → service `:8080` → pod.

**First-run chicken-and-egg:** AdGuard's setup wizard runs on port 3000. Needed `kubectl port-forward svc/adguard 3000:80` to complete initial config, then switched `targetPort` to `8080` after setup.

### DNS rewrite configuration

In AdGuard admin UI — Filters → DNS rewrites:
```
Domain: *.homelab   →   Answer: 100.93.76.126  (Tailscale IP)
```

This wildcard matches any `*.homelab` domain and returns the node's Tailscale IP where Traefik listens.

### Tailscale Split DNS

Tailscale admin console → DNS → Split DNS:
```
Domain: homelab
Nameserver: 100.93.76.126
```

Tailscale routes all `*.homelab` queries to the node's Tailscale IP, where AdGuard is listening on port 53.

---

## Result

```
Tailnet device
  │
  ▼ query *.homelab
Tailscale (100.100.100.100)
  │
  ▼ Split DNS → 100.93.76.126:53
AdGuard (hostNetwork, host port 53 TCP+UDP)
  │
  ▼ DNS rewrite *.homelab → 100.93.76.126
Browser connects to 100.93.76.126:80
  │
  ▼ Host port 80 → Traefik (NodePort 32094)
Ingress matches Host header → service → pod
```

**Three independent DNS paths, no overlap:**

| Path | Resolver | Scope |
|---|---|---|
| Host | `systemd-resolved` (127.0.0.53) | Local processes |
| Pods | `CoreDNS` (10.43.0.10) | Cluster workloads |
| Tailnet | `AdGuard` (100.93.76.126:53) | External devices |

**Key outcomes:**
- UDP and TCP DNS both work (no hostPort gap)
- No conflict with systemd-resolved (different bind IPs)
- No conflict with Traefik (AdGuard admin on 8080, Traefik owns 80)
- Single wildcard rewrite covers all `.homelab` domains
- No `kubectl apply` needed — ArgoCD syncs from git

---

## Lessons

- `hostPort` is unreliable for UDP in k3s. Use `hostNetwork` for DNS servers.
- With `hostNetwork`, port conflicts on the host are your problem — plan port allocation.
- AdGuard's setup wizard runs on port 3000, admin UI on 80. Change it before switching to `hostNetwork`.
- Three independent DNS paths = robust design. No single failure takes down all DNS.
- Iptables DNAT (used by hostPort) and `hostNetwork` achieve the same result — `hostNetwork` is simpler and protocol-complete.
