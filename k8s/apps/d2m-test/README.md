# d2m-test

Test app (D2M for Windows).

## Reach it

| Where | URL / address |
|---|---|
| Tailnet/LAN HTTP | http://d2m-test.homelab |
| In-cluster | http://d2m-test.apps.svc:80 |

Not exposed publicly.

## Config

- Image: `ghcr.io/adi-amatdev/d2m-windows:latest`
- Routing: `service.yaml` (Service + Ingress for `d2m-test.homelab`)
