# minio

S3-compatible object storage. Holds blog images.

## Reach it

| Where | URL / address |
|---|---|
| S3 API (Tailnet/LAN HTTP) | http://s3.homelab |
| Console (Tailnet/LAN HTTP) | http://minio.homelab |
| Public images (via blog host) | https://dhridata.tail6a3e40.ts.net/s3/blogs/... |
| S3 API in-cluster | http://minio.cloud.svc:9000 |
| Console in-cluster | http://minio.cloud.svc:9001 |

Never funneled publicly. Only public paths are blog images via the `/s3` route in
`apps/blogs/ingress.yaml` (prefix stripped, minio sees `/blogs/<key>`).

## Config

- Image: `quay.io/minio/minio:latest`
- Creds: `minio-secret` (`MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`)
- Data: hostPath `/home/aadi/store/minio-data`
- Console redirect: `http://minio.homelab`
- Routing: `ingress.yaml` (`s3.homelab`, `minio.homelab`)
