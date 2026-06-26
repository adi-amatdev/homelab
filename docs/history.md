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

**Lessons etched into memory:**
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

This was the most iterative phase. The goal: replace `/etc/hosts` with proper internal DNS so every device on my Tailnet could resolve `*.homelab` domains.

**Attempt 1 — Service-only (fail):** Deployed AdGuard with a ClusterIP service and Ingress. DNS port 53 wasn't reachable outside the cluster. Tailnet devices couldn't query it.

**Attempt 2 — hostPort (partial fail):** Added `hostPort: 53` to the Deployment. k3s only bound TCP, leaving UDP at port 0. DNS resolution was broken for UDP queries.

**Attempt 3 — hostNetwork (success):** Switched to `hostNetwork: true`. AdGuard binds directly to the host's network stack — port 53 (TCP+UDP) and port 8080 (admin UI) are on the host itself. Traefik keeps port 80 for HTTP routing via kube-proxy.

**The chicken-and-egg problem:** To configure AdGuard, you need to reach its web UI. But the web UI domain (`adguard.homelab`) needs DNS resolution. Solution: port-forward to the setup wizard on port 3000, complete initial config, then switch to the admin UI on port 8080.

**Architecture win:** Three independent DNS paths — tailnet devices → AdGuard, pods → CoreDNS, host → systemd-resolved. No single point of failure.

---

## What's Next

- cert-manager for TLS
- Cloudflared tunnel for public access
- Prometheus + Grafana monitoring
- More apps on the platform
