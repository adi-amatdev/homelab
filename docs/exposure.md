# Exposure Strategy

How every service is exposed, inside and outside the tailnet. Managed by Traefik
(Ingress/IngressRoute) at the edge + Tailscale Serve/Funnel on the k3s node
(`dhridata`).

**Constraint:** Tailscale Serve/Funnel only serves the node's own MagicDNS name
(`dhridata.tail6a3e40.ts.net`). There are no extra hostnames — routing is done by
**path**, and public vs private is split across two Traefik entrypoints:

| Entrypoint | Port | Reached by | Routes |
|---|---|---|---|
| `web` | 80 | Tailscale Funnel (public, 443→80) + tailnet/LAN `.homelab` | blog `/`, images `/s3/*`. `/admin` has no route → 404 |
| `private` | 8081 | Tailscale Serve (tailnet-only, 8443→8081) | blog `/admin`, images `/s3/*` |

## Public (Funnel) — `https://dhridata.tail6a3e40.ts.net`

| Path | Backend | Notes |
|---|---|---|
| `/` | blogs (:3000) | Public blog |
| `/s3/*` | minio (:9000) | Public images, `/s3` prefix stripped |
| `/admin` | — | No route → 404 |

## Private (Serve) — tailnet only

`https://dhridata.tail6a3e40.ts.net:8443`

| Path | Backend | Notes |
|---|---|---|
| `/admin` | blogs (:3000) | Blog admin |
| `/s3/*` | minio (:9000) | S3 API (via prefix strip) |

## Tailnet/LAN HTTP (legacy, still active)

`blogs.homelab`, `s3.homelab`, `minio.homelab`, `adguard.homelab`, `argocd.homelab`, `d2m-test.homelab`.

## Never public

- PostgreSQL, Redis — in-cluster `ClusterIP` only (no external service/TCP passthrough)
- ArgoCD, AdGuard admin, MinIO console — tailnet/LAN HTTP only

## Node config (not in git)

```bash
sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
sudo tailscale funnel --bg --https=443 http://127.0.0.1:80
```

## Repo config locations

- `k8s/platform/traefik/config.yaml` — adds `private` entrypoint (8081), no `postgres` port
- `k8s/apps/blogs/ingress.yaml` — public `/` + `/s3` (web), private `/admin` + `/s3` (private), prefix-strip middleware
- `k8s/apps/blogs/.env` — `SITE_URL`/`S3_PUBLIC_URL` point at the public host
- `k8s/cloud/minio/ingress.yaml`, `k8s/cloud/adguard/ingress.yaml` — `.homelab` hosts only
- `k8s/platform/argocd/values.yaml` — `server.ingress` hostname `argocd.homelab`
