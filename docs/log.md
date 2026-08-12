# Update Log

## 2026-08-12
- **Security fix**: Pinned every `.homelab` Ingress to the `web` entrypoint. Traefik attaches plain Ingress routes to all entrypoints, so `.homelab` apps were reachable on the funneled `public` entrypoint via Host-header spoofing while the blog funnel was live. Added `traefik.ingress.kubernetes.io/router.entrypoints: web` to blogs, d2m-test, minio, adguard, argocd-server; documented the rule in `exposure.md`, `knowledge.md`, `add-app.md`, and `templates/service.yaml`.

## 2026-06-26
- **Creation**: Added AdGuard Home postmortem for internal DNS solution.
- **Enrichment**: Added cross-links between concepts.

## 2026-06-25
- **Creation**: Added kubectl quick reference.
- **Creation**: Added stateful services (PostgreSQL, Redis).

## 2026-06-22
- **Update**: Documented the Great Restructure and extracted lessons learned.

## 2026-06-21
- **Creation**: Initial foundation — k3s, ArgoCD, Traefik, MinIO.

## 2026-06-10
- **Initialization**: Bundle created.
