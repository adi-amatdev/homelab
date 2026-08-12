# homelab

Personal Kubernetes homelab on k3s. Fully GitOps — push to git, cluster self-updates via ArgoCD.

---

## Stack

| Layer | Tool |
|---|---|
| Cluster | k3s |
| GitOps | ArgoCD |
| Ingress | Traefik |
| DNS | AdGuard Home (Tailnet Split DNS) |
| Registry | GHCR |

---

## How it works

```
git push
  └── ArgoCD detects change
        └── applies manifests to cluster
              └── cluster self-heals to match git
```

One rule: **git is the source of truth**. Never `kubectl apply` manually unless bootstrapping.

---

## Deployments

| Service | Namespace | Access |
|---|---|---|
| ArgoCD | `infra` | argocd.homelab |
| Traefik | `infra` | traefik.homelab (dashboard) |
| Blog | `apps` | **Public**: dhridata.tail6a3e40.ts.net (Funnel). **Admin**: dhridata.tail6a3e40.ts.net:8443/admin (Serve, tailnet only). `/admin` blocked on public host |
| MinIO | `cloud` | minio.homelab, s3.homelab; public images via blog host `/s3/*` |
| PostgreSQL | `cloud` | postgres.cloud.svc.cluster.local:5432 (ClusterIP only, never public) |
| Redis | `cloud` | redis.cloud.svc.cluster.local:6379 (ClusterIP only, never public) |
| AdGuard Home | `cloud` | adguard.homelab (admin); tailnet-ip:53 (DNS) |
| d2m-test | `apps` | d2m-test.homelab |

Full exposure map: see `docs/exposure.md`.

---

## Repo Structure

```
k8s/
  platform/              — platform components (applied manually)
    argocd/              — ArgoCD install (Helm via Kustomize)
    traefik/             — ingress controller (Helm via Kustomize)
  cloud/                 — shared infra services
    minio/
    postgres/
    redis/
    adguard/
  apps/                  — personal projects
    d2m-test/
argocd-apps/             — app-of-apps registry (auto-synced by root)
  root.yaml              — the only manifest ever manually applied
  cloud/                 — ArgoCD Applications for cloud services
  apps/                  — ArgoCD Applications for app projects
docs/
  knowledge.md           — how everything works
  kubectl.md             — debug commands
  add-app.md             — adding a new app
  lessons.md             — mistakes documented
  history.md             — project history & challenges
templates/               — copy these to add new apps
```

---

## Bootstrap

ArgoCD and Traefik are deployed via Kustomize + Helm. Run these once:

```bash
kustomize build --enable-helm k8s/platform/traefik/ | kubectl apply -f -
kustomize build --enable-helm k8s/platform/argocd/ | kubectl apply -f -
kubectl apply -f argocd-apps/root.yaml
```

The last command is the **only** `kubectl apply` you'll ever need again.

---

## Adding a New App

```bash
cp templates/deployment.yaml k8s/apps/<your-app>/deployment.yaml
cp templates/service.yaml k8s/apps/<your-app>/service.yaml
cp templates/kustomization.yaml k8s/apps/<your-app>/kustomization.yaml
cp templates/argocd-app.yaml argocd-apps/apps/<your-app>.yaml
# edit files — set name, image, port, namespace
git add . && git commit -m "add <your-app>" && git push
```

ArgoCD picks it up automatically in ~3 minutes. See `docs/add-app.md` for details.

---

## Namespaces

| Namespace | Purpose |
|---|---|
| `infra` | ArgoCD, Traefik |
| `cloud` | MinIO, PostgreSQL, Redis, AdGuard Home |
| `apps` | Personal projects |
