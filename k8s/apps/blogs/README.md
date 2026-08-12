# blogs

Personal blog (Next.js). GitOps via ArgoCD.

## Reach it

| Where | URL / address |
|---|---|
| Public (Tailscale Funnel) | https://dhridata.tail6a3e40.ts.net |
| Public images | https://dhridata.tail6a3e40.ts.net/s3/blogs/... |
| Admin (public, password-protected) | https://dhridata.tail6a3e40.ts.net/admin |
| Tailnet/LAN HTTP | http://blogs.homelab |
| In-cluster | http://blogs.apps.svc:3000 |

`/admin` is served on the public entrypoint (protected by the app's password).
The blog is a single entrypoint (`public`), no separate private admin entrypoint.

## Config

- Image: `ghcr.io/adi-amatdev/blog:latest`
- Env: `blogs-env` secret (created from `.env`, which is gitignored — rebuild with
  `kubectl create secret generic blogs-env --from-env-file=.env -n apps`)
- Routing: `ingress.yaml` (public IngressRoute, `/s3` prefix strip)
