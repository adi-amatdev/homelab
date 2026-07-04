---
type: Timeline
title: Homelab Build History
description: Chronological record of building the homelab, covering foundations, restructuring, stateful services, and DNS.
tags: [homelab, kubernetes, infrastructure]
timestamp: 2026-06-26T00:00:00Z
---

# Homelab History

A chronological record of building this homelab, written so I can turn it into a blog post later.

---

## Phase 1: Foundation (June 19–21)

**Commit: `init`**

Started with a single k3s node on an Ubuntu machine. The goal: learn Kubernetes by running real services at home. Initialized the repo with ArgoCD as the GitOps engine and Traefik as the ingress controller — both deployed via Kustomize with Helm charts.

First real service was **MinIO** (S3-compatible storage). Getting it right took several iterations — the console redirect URL, hostAliases for local DNS resolution, and getting the ports right. Lesson: even "simple" deployments need multiple fix cycles when you're learning.

**Key challenges:**
- MinIO redirect URLs and browser redirect quirks
- Understanding how hostAliases work for local name resolution inside pods

---

## Phase 2: The Great Restructure (June 22)

**Commits: `structural changes` → `Revert "structural changes"` → `structural : no break expected`**

This was the defining moment of the project — and the most painful. I tried to do too much at once:

1. Removed `namespace.yaml` from all apps (consolidating into shared namespaces)
2. Replaced Kustomize helmCharts with native Helm for platform components
3. Moved `argocd-apps` from platform/ to repo root
4. Added domain parameterization via Kustomize vars

Everything broke. ArgoCD couldn't sync. Traefik went down. I had no ingress, no GitOps. The revert commits tell the story — I rolled back, regrouped, and re-approached one change at a time.

**Lessons etched into memory (full details in [lessons learned](/lessons.md)):**
- `prune: true` deletes entire namespaces, secrets and all
- Kustomize vars work locally but fail in ArgoCD's different version
- Platform infra (ingress, GitOps) is critical path — change it in isolation
- One thing per commit. Always.

The restructure eventually succeeded by doing each change separately: move files, verify, commit, deploy.

---

## Phase 3: Stateful Services (June 22–25)

**Commits: `postgres`, `redis`**

With a stable cluster, I added stateful services:

- **PostgreSQL** — exposed externally via Traefik IngressRouteTCP on port 5432
- **Redis** — internal-only, for apps to consume

Both use hostPath storage under `/home/aadi/store/`. The pattern was set: Kustomize + ArgoCD Application, namespace `cloud` for shared infra services.

---

## Phase 4: Internal DNS with AdGuard Home (June 25–26)

**Commits: `adgaurd fix` → `adgaurd fix` → `adgaurd fix` → `decoupled dns`**

This was the most iterative phase (see the [full postmortem](/solved/internal-dns-with-adguard.md)). The goal: replace `/etc/hosts` with proper internal DNS so every device on my Tailnet could resolve `*.homelab` domains.

**Attempt 1 — Service-only (fail):** Deployed AdGuard with a ClusterIP service and Ingress. DNS port 53 wasn't reachable outside the cluster. Tailnet devices couldn't query it.

**Attempt 2 — hostPort (partial fail):** Added `hostPort: 53` to the Deployment. k3s only bound TCP, leaving UDP at port 0. DNS resolution was broken for UDP queries.

**Attempt 3 — hostNetwork (success):** Switched to `hostNetwork: true`. AdGuard binds directly to the host's network stack — port 53 (TCP+UDP) and port 8080 (admin UI) are on the host itself. Traefik keeps port 80 for HTTP routing via kube-proxy.

**The chicken-and-egg problem:** To configure AdGuard, you need to reach its web UI. But the web UI domain (`adguard.homelab`) needs DNS resolution. Solution: port-forward to the setup wizard on port 3000, complete initial config, then switch to the admin UI on port 8080.

**Architecture win:** Three independent DNS paths — tailnet devices → AdGuard, pods → CoreDNS, host → systemd-resolved. No single point of failure.

---

## Phase 5: First App + Secrets (July 4)

**Commits: `okf bundle, blogs and sealed secret deployment` → `purge sealed-secrets` → multiple fixes**

Deployed the first real application — a Next.js blog. Started by attempting Sealed Secrets for env var management, which failed due to `.gitignore` patterns, ArgoCD helmCharts incompatibility, and Docker permission issues.

**Resolution:** Dropped Sealed Secrets entirely. Use plain Kubernetes Secrets created from a local `.env` file. k3s has `--secrets-encryption` enabled, so secrets are encrypted at rest in etcd — good enough for a single-node homelab.

**Key fixes during deployment:**
- `.env` file values must not have quotes — `--from-env-file` treats them literally
- Pod-to-pod DNS uses `<service>.<namespace>`, not `.homelab` (CoreDNS doesn't resolve `.homelab`)
- Image name `blog` vs `blogs` — verify GHCR repo name matches the deployment image
- Only one ArgoCD app should own a namespace via `namespace.yaml`

**Current state:** Blog is running at `http://blogs.homelab` with DATABASE_URL pointing to `postgres.cloud`, connected to the Postgres instance in the `cloud` namespace.

**Commits: `okf bundle, blogs and sealed secret deployment` → `purge sealed-secrets`**

Attempted to deploy Sealed Secrets for managing environment variables via GitOps. Failed spectacularly:

- The ArgoCD Application file was silently ignored by `.gitignore` (`*-secrets.yaml` pattern)
- Platform helmCharts kustomizations can't be managed by ArgoCD Applications without `--enable-helm` (the CRD didn't accept our `kustomize.enableHelm` field)
- Docker-based kubeseal required docker group membership that didn't exist
- Blogs app namespace conflicted with d2m-test's namespace ownership
- Image name typo (`blogs` vs `blog`) caused ErrImagePull

**Result:** Sealed Secrets ejected entirely. Blogs app deployed without env vars. If you want secret management in the future, use a different approach — either pre-seal on a machine with the cluster cert, or use External Secrets Operator, or just manage secrets by hand since this is a single-node homelab.

**Lessons (full details in [lessons learned](/lessons.md)):**
- `.gitignore` silently ignores files matching its patterns — always check with `git check-ignore`
- Two ArgoCD apps can't own the same namespace via namespace.yaml
- Verify image names and tags in GHCR before deploying
- Platform components with helmCharts need manual bootstrapping

---

## What's Next

- cert-manager for TLS
- Cloudflared tunnel for public access
- Prometheus + Grafana monitoring
- More apps on the platform
