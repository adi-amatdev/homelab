# traefik

Ingress controller / edge router. Applied manually (not self-managed).

## Reach it

| Entrypoint | Port | Notes |
|---|---|---|
| `web` | 80 | Public + tailnet/LAN HTTP, reached by Tailscale Funnel (443->80) |
| `websecure` | 443 | TLS termination (unused for now) |
| `private` | 8081 | Tailnet-only, reached by Tailscale Serve (8443->8081) for admin routes |

| Where | URL / address |
|---|---|
| Dashboard (Tailnet/LAN HTTP) | http://traefik.homelab/dashboard |
| Private entrypoint | 127.0.0.1:8081 / 192.168.1.21:8081 |
| In-cluster | traefik.infra.svc |

Routes come from Kubernetes Ingresses and Traefik IngressRoutes (CRDs).

## Config

- Chart: `traefik` 34.4.1 (`charts/`), rendered by kustomize
- `config.yaml` — entrypoints, `kubernetesCRD` + `kubernetesIngress` providers, dashboard route

## Apply

```bash
kustomize build --enable-helm k8s/platform/traefik/ | kubectl apply -f -
```
