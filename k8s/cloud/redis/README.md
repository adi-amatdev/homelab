# redis

Redis 7 with AOF + snapshotting.

## Reach it

| Where | URL / address |
|---|---|
| In-cluster (ClusterIP only) | redis.cloud.svc.cluster.local:6379 |
| From other namespaces | redis.cloud.svc:6379 |
| From a pod | redis:6379 (if in `cloud` ns) |

Never public. ClusterIP only.

## Config

- Image: `redis:7-alpine`
- Args: `--appendonly yes --save 60 1`
- Data: hostPath `/home/aadi/store/redis-data`
