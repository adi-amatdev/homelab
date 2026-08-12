# Exposure Strategy

How every service is exposed, inside and outside the tailnet. Managed by Traefik
(Ingress/IngressRoute) at the edge + Tailscale Funnel on the k3s node
(`dhridata`).

**Constraint:** Tailscale Funnel only serves the node's own MagicDNS name
(`dhridata.tail6a3e40.ts.net`). No extra hostnames — routing is done by **path**,
and what is public is decided by the **Traefik entrypoint** the Funnel points at.
Only the `public` entrypoint is ever funneled, so whatever it carries is all that
can be public.

**DNS/name resolution:** `*.homelab` (AdGuard split-DNS) and
`dhridata.tail6a3e40.ts.net` (MagicDNS/public DNS) both resolve to
`100.93.76.126` — the **port** you connect on picks the entrypoint. See
[dns.md](./dns.md) for the full flow diagram.

| Entrypoint | Port | Reached by | Routes |
|---|---|---|---|
| `public` | 8082 | Tailscale Funnel (public, 443→8082) | blog `/`, `/admin`, images `/s3/*` (Host `dhridata.tail6a3e40.ts.net`) |
| `web` | 80 | Tailnet/LAN `.homelab` HTTP only | blogs.homelab, s3/minio.homelab, adguard.homelab, argocd.homelab, traefik.homelab. **Not funneled** |

## Public (Funnel) — `https://dhridata.tail6a3e40.ts.net`

| Path | Backend | Notes |
|---|---|---|
| `/` | blogs (:3000) | Public blog |
| `/admin` | blogs (:3000) | Blog admin (password-protected by the app) |
| `/s3/*` | minio (:9000) | Public images, `/s3` prefix stripped |

Everything else lives on the `web` entrypoint. Because Funnel points at `public`
(8082) — never `web` — `.homelab` apps can't be reached from the internet, even
by spoofing the Host header.

**Important:** Traefik attaches plain `Ingress` routes to *every* entrypoint by
default. Every `.homelab` Ingress MUST carry
`traefik.ingress.kubernetes.io/router.entrypoints: web` (see the
`templates/service.yaml`). Without it the service leaks onto the funneled
`public` entrypoint.

**Important:** The `blogs-public` IngressRoute references MinIO across namespaces
(`cloud/minio`). Traefik's kubernetesCRD provider needs
`allowCrossNamespace: true` (`k8s/platform/traefik/config.yaml`) or the `/s3`
router silently never exists. Rules also need explicit `priority` — the `/s3` and
`/admin` rules use `priority: 100` to outrank the catch-all `/` rule
(`priority: 50`); Traefik's default priority is rule length and a catch-all like
`Host(...)` alone would otherwise lose or win unpredictably.

## Tailnet/LAN HTTP (legacy, still active)

`blogs.homelab`, `s3.homelab`, `minio.homelab`, `adguard.homelab`, `argocd.homelab`.

## Never public

- PostgreSQL, Redis — in-cluster `ClusterIP` only (no external service/TCP passthrough)
- ArgoCD, AdGuard admin, MinIO console — `.homelab` only, `web` entrypoint is never funneled

## Node config (not in git)

```bash
# public blog + admin + images (everything on the "public" entrypoint)
sudo tailscale funnel --bg --https=443 http://127.0.0.1:8082
```

## Repo config locations

- `k8s/platform/traefik/config.yaml` — entrypoints `web`(80), `public`(8082)
- `k8s/apps/blogs/ingress.yaml` — `blogs-public` on `public` entrypoint, prefix-strip middleware
- `k8s/apps/blogs/.env` — `SITE_URL`/`S3_PUBLIC_URL` point at the public host
- `k8s/cloud/minio/ingress.yaml`, `k8s/cloud/adguard/ingress.yaml` — `.homelab` hosts only
- `k8s/platform/argocd/values.yaml` — `server.ingress` hostname `argocd.homelab`
