# postgres

PostgreSQL 17, shared database.

## Reach it

| Where | URL / address |
|---|---|
| In-cluster (ClusterIP only) | postgres.cloud.svc.cluster.local:5432 |
| From other namespaces | postgres.cloud.svc:5432 |
| From a pod | postgres:5432 (if in `cloud` ns) |

Never public. ClusterIP only — no external service, no TCP passthrough.

## Config

- Image: `postgres:17`
- Creds: `postgres-secret` (`POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB`)
- Data: hostPath `/home/aadi/store/postgres-data`

Example in-app URL: `postgresql://<user>:<pass>@postgres.cloud:5432/<db>`
