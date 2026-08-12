# blogs

Personal blog (Next.js). GitOps via ArgoCD.

## Reach it

| Where | URL / address |
|---|---|
| Public (Tailscale Funnel) | https://dhridata.tail6a3e40.ts.net |
| Public images | https://dhridata.tail6a3e40.ts.net/s3/blogs/... |
| Admin (Tailscale Serve, tailnet only) | https://dhridata.tail6a3e40.ts.net:8443/admin |
| Tailnet/LAN HTTP | http://blogs.homelab |
| In-cluster | http://blogs.apps.svc:3000 |

`/admin` on the public host has no route -> 404. Admin only exists on the private
entrypoint (`:8443/admin`), reachable over the tailnet only.

## Config

- Image: `ghcr.io/adi-amatdev/blog:latest`
- Env: `blogs-env` secret (created from `.env`, which is gitignored — rebuild with
  `kubectl create secret generic blogs-env --from-env-file=.env -n apps`)
- Routing: `ingress.yaml` (public + private IngressRoutes, `/s3` prefix strip)
