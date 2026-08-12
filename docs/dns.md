---
type: Reference
title: DNS & Traffic Flows
description: How DNS resolution and traffic reach every service — the two DNS namespaces (*.ts.net vs *.homelab), the ports that pick the Traefik entrypoint, and the routing inside.
tags: [dns, tailscale, adguard, traefik, networking]
---

# DNS & Traffic Flows

Two DNS namespaces exist, and both resolve to the **same IP** (`100.93.76.126`,
the node's Tailscale address). What decides where traffic actually goes is the
**port** — not the name.

## The mental model

```
Name resolution  → 100.93.76.126 (always)
Port you connect on  → Traefik entrypoint
Host header + path  → the app
```

| Name | Who resolves it | Resolves to | Connect on | Entrypoint |
|---|---|---|---|---|
| `*.homelab` (e.g. `blogs.homelab`) | AdGuard split-DNS (tailnet only) | `100.93.76.126` | **80** | `web` |
| `dhridata.tail6a3e40.ts.net` | Tailscale MagicDNS (tailnet) **and** Tailscale public DNS (internet) | `100.93.76.126` | **443** (Funnel) | `public` :8082 |
| `dhridata.tail6a3e40.ts.net` | same as above | `100.93.76.126` | **8443** (Serve) | `private` :8081 |

So `dhridata.tail6a3e40.ts.net:443` and `:8443` reach *different* entrypoints of
the *same* hostname — the port is the router.

## Diagram

```mermaid
flowchart TB
    subgraph internet["Public Internet"]
        pub["Any browser<br/>(only once Funnel is on)"]
        taildns["Tailscale public DNS<br/>(*.ts.net is globally resolvable)"]
        funneledge["Tailscale Funnel edge"]
    end

    subgraph tailnet["Tailscale Tailnet"]
        dev["Tailnet device<br/>(laptop, phone, godel)"]
        mdns["Tailscale MagicDNS<br/>100.100.100.100"]
        adg["AdGuard Home :53<br/>100.93.76.126 (hostNetwork)"]
        ts["Tailscale on dhridata"]
        funnel["Funnel 443 → 127.0.0.1:8082"]
        serve["Serve 8443 → 127.0.0.1:8081"]
    end

    subgraph node["dhridata — Traefik edge router"]
        e_web["web :80<br/>(NOT funneled)"]
        e_pub["public :8082<br/>(funneled, only public routes)"]
        e_priv["private :8081<br/>(tailnet only)"]
    end

    subgraph k8s["k8s cluster"]
        blog["blogs :3000"]
        minio["minio :9000"]
        others["argocd · adguard · d2m-test · traefik dashboard"]
        coredns["CoreDNS 10.43.0.10"]
    end

    subgraph host["Host (dhridata OS)"]
        resolved["systemd-resolved<br/>127.0.0.53"]
    end

    %% *.homelab (tailnet, via AdGuard)
    dev -- "1. query blogs.homelab" --> mdns
    mdns -- "2. Split DNS: 'homelab' → 100.93.76.126" --> adg
    adg -- "3. rewrite *.homelab → 100.93.76.126" --> dev
    dev -- "4. http://100.93.76.126:80 · Host: blogs.homelab" --> e_web
    e_web -- "blogs.homelab" --> blog
    e_web -- "s3/minio/adguard/argocd/... .homelab" --> others

    %% dhridata.ts.net — private (tailnet)
    dev -- "5. query dhridata.tail6a3e40.ts.net" --> mdns
    mdns -- "6. MagicDNS → 100.93.76.126" --> dev
    dev -- "7. https://dhridata.tail6a3e40.ts.net:8443" --> serve
    serve -- "proxies to 127.0.0.1:8081" --> e_priv
    e_priv -- "/admin, /s3" --> blog
    e_priv -- "/s3" --> minio

    %% dhridata.ts.net — public (internet)
    pub -- "8. query dhridata.tail6a3e40.ts.net" --> taildns
    taildns -- "resolves to Funnel edge" --> funneledge
    pub -- "9. https://dhridata.tail6a3e40.ts.net:443" --> funneledge
    funneledge -- "WireGuard tunnel" --> funnel
    funnel -- "proxies to 127.0.0.1:8082" --> e_pub
    e_pub -- "/ → blog (public), /s3/* → minio" --> blog
    e_pub --> minio

    %% in-cluster DNS
    blog -- "postgres.cloud:5432 · redis.cloud:6379" --> coredns
```

## The three independent DNS paths (unchanged)

| Path | Resolver | Scope |
|---|---|---|
| Tailnet devices | AdGuard (100.93.76.126:53) | `*.homelab` → Tailscale IP |
| Pods | CoreDNS (10.43.0.10) | `<svc>.<ns>.svc.cluster.local` — `.homelab` is **NXDOMAIN** in-cluster |
| Host | systemd-resolved (127.0.0.53) | upstream 1.1.1.1 |

Pods never use `.homelab` — the blog connects to `postgres.cloud:5432`, not
`postgres.homelab`.

## Common confusion

- **Same IP, different result** — `100.93.76.126` is the answer to both
  `blogs.homelab` and `dhridata.tail6a3e40.ts.net`. The port (`80`/`443`/`8443`)
  picks the Traefik entrypoint, then Host+path picks the app.
- **`.ts.net` is not only MagicDNS** — the same name is resolvable on the public
  internet by Tailscale's DNS, which is what makes Funnel work without a public
  DNS entry.
- **Funnel exposes only `public` :8082** — no amount of Host-header tricks can
  reach `web` :80 routes (argocd, adguard, etc.) from the internet.

See also: [exposure.md](./exposure.md) for the full route table,
[knowledge.md](./knowledge.md#dns-architecture) for the original design.
