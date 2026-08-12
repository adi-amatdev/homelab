# Exposure Strategy

How every service is exposed, inside and outside the tailnet. Managed by Traefik
(Ingress/IngressRoute) at the edge + Tailscale Serve/Funnel on the k3s node
(`dhridata`).

**Constraint:** Tailscale Serve/Funnel only serves the node's own MagicDNS name
(`dhridata.tail6a3e40.ts.net`). No extra hostnames — routing is done by **path**,
and public vs private is separated at the **Traefik entrypoint** level. Only the
`public` entrypoint is ever funneled, so whatever it carries is all that can be
public.

**DNS/name resolution:** `*.homelab` (AdGuard split-DNS) and
`dhridata.tail6a3e40.ts.net` (MagicDNS/public DNS) both resolve to
`100.93.76.126` — the **port** you connect on picks the entrypoint. See
[dns.md](./dns.md) for the full flow diagram.

| Entrypoint | Port | Reached by | Routes |
|---|---|---|---|
| `public` | 8082 | Tailscale Funnel (public, 443→8082) | blog `/`, images `/s3/*` (Host `dhridata.tail6a3e40.ts.net`). `/admin` has no route → 404 |
| `web` | 80 | Tailnet/LAN `.homelab` HTTP only | blogs.homelab, s3/minio.homelab, adguard.homelab, argocd.homelab, d2m-test.homelab, traefik.homelab. **Not funneled** |
| `private` | 8081 | Tailscale Serve (tailnet-only, 8443→8081) | blog `/admin`, images `/s3/*` |

## Public (Funnel) — `https://dhridata.tail6a3e40.ts.net`

| Path | Backend | Notes |
|---|---|---|
| `/` | blogs (:3000) | Public blog |
| `/s3/*` | minio (:9000) | Public images, `/s3` prefix stripped |
| `/admin` | — | No route → 404 |

Everything else lives on the `web` entrypoint. Because Funnel points at `public`
(8082) — never `web` — `.homelab` apps can't be reached from the internet, even
by spoofing the Host header.

**Important:** Traefik attaches plain `Ingress` routes to *every* entrypoint by
default. Every `.homelab` Ingress MUST carry
`traefik.ingress.kubernetes.io/router.entrypoints: web` (see the
`templates/service.yaml`). Without it the service leaks onto the funneled
`public` entrypoint.

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
- ArgoCD, AdGuard admin, MinIO console — `.homelab` only, `web` entrypoint is never funneled

## Node config (not in git)

```bash
# private admin over the tailnet
sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
# public blog (only the "public" entrypoint routes become public)
sudo tailscale funnel --bg --https=443 http://127.0.0.1:8082
```

## Repo config locations

- `k8s/platform/traefik/config.yaml` — entrypoints `web`(80), `public`(8082), `private`(8081)
- `k8s/apps/blogs/ingress.yaml` — `blogs-public` on `public` entrypoint, `blogs-private` on `private`, prefix-strip middleware
- `k8s/apps/blogs/.env` — `SITE_URL`/`S3_PUBLIC_URL` point at the public host
- `k8s/cloud/minio/ingress.yaml`, `k8s/cloud/adguard/ingress.yaml` — `.homelab` hosts only
- `k8s/platform/argocd/values.yaml` — `server.ingress` hostname `argocd.homelab`
