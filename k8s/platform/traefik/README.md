# traefik

Ingress controller / edge router. Applied manually (not self-managed).

## Reach it

| Entrypoint | Port | Notes |
|---|---|---|
| `web` | 80 | Tailnet/LAN `.homelab` HTTP, NOT funneled |
| `public` | 8082 | Funneled to the internet (443->8082); carries blog `/`, `/admin`, `/s3/*` |
| `websecure` | 443 | TLS termination (unused for now) |

| Where | URL / address |
|---|---|
| Dashboard (Tailnet/LAN HTTP) | http://traefik.homelab/dashboard |
| In-cluster | traefik.infra.svc |

Routes come from Kubernetes Ingresses and Traefik IngressRoutes (CRDs).

## Config

- Chart: `traefik` 34.4.1 (`charts/`), rendered by kustomize
- `config.yaml` — entrypoints, `kubernetesCRD` + `kubernetesIngress` providers, dashboard route

## Apply

```bash
kustomize build --enable-helm k8s/platform/traefik/ | kubectl apply -f -
```
