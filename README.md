# homelab

Personal Kubernetes homelab on k3s. Fully GitOps — push to git, cluster self-updates via ArgoCD.

> Architecture diagram coming soon.

---

## Stack

| Layer | Tool |
|---|---|
| Cluster | k3s |
| GitOps | ArgoCD |
| Ingress | Traefik |
| TLS | cert-manager + Let's Encrypt |
| Tunnel | Cloudflared |
| Registry | GHCR |
| Monitoring | Prometheus + Grafana |

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

## Repo Structure

```
platform/
  argocd/                — ArgoCD install (Helm via Kustomize)
    kustomization.yaml
    values.yaml
    namespace.yaml
  traefik/               — ingress controller (Helm via Kustomize)
    kustomization.yaml
    config.yaml
  argocd-apps/           — app-of-apps registry
    root.yaml            — the only manifest ever manually applied
    _template.yaml       — copy this for each new app
apps/                    — k8s manifests per app
  _template/             — copy this for each new app
docs/
  knowledge.md           — how everything works
  kubectl.md             — debug commands
  add-app.md             — adding a new app
```

---

## Bootstrap

ArgoCD and Traefik are deployed via Kustomize + Helm. Run these once to stand up the cluster:

```bash
# 1. deploy traefik
kustomize build --enable-helm platform/traefik/ | kubectl apply -f -

# 2. deploy argocd
kustomize build --enable-helm platform/argocd/ | kubectl apply -f -

# 3. bootstrap the root app — once, ever
kubectl apply -f platform/argocd-apps/root.yaml
```

Step 3 is the **only** `kubectl apply` that ever needs to run again. After that, everything is git.

---

## Adding a New App

```bash
cp -r apps/_template apps/<your-app>
cp platform/argocd-apps/_template.yaml platform/argocd-apps/<your-app>.yaml
# edit both — update name, namespace, image, host
git add . && git commit -m "add <your-app>" && git push
```

The root ArgoCD app watches `platform/argocd-apps/` — your new app is picked up automatically. No `kubectl apply` needed. See `docs/add-app.md` for the full walkthrough.

---

## Namespaces

| Namespace | Purpose |
|---|---|
| `infra` | ArgoCD, Traefik, cert-manager, cloudflared |
| `apps` | All personal projects |
| `monitoring` | Prometheus, Grafana |
| `ai` | Ollama, LiteLLM, OpenWebUI |
| `cloud` | MinIO, LocalStack |

<!--
## Apps

| App | Namespace |
|---|---|
| d2m-test | apps |
| portfolio | apps |
| api | apps |
| rag / knowledge platform | apps |
| jobtracker | apps |
| ollama | ai |
| litellm | ai |
| openwebui | ai |
| minio | cloud |
| localstack | cloud |
-->
