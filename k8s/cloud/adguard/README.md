# adguard

DNS / ad-blocking on the tailnet (AdGuard Home).

## Reach it

| Where | URL / address |
|---|---|
| Admin UI (Tailnet/LAN HTTP) | http://adguard.homelab |
| DNS (TCP/UDP 53) | tailnet IP `100.93.76.126:53` |
| In-cluster | http://adguard.cloud.svc:80 |

Never expose the admin UI publicly. DNS serves the tailnet + LAN (hostNetwork pod).

## Config

- Image: `adguard/adguardhome` (digest-pinned)
- Config: `configmap.yaml` -> `/opt/adguardhome/conf/AdGuardHome.yaml`
- Data: hostPath `/home/aadi/store/adguard-work`, `/home/aadi/store/adguard-conf`
- Routing: `ingress.yaml` (`adguard.homelab`)
