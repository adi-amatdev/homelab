# argocd

GitOps controller. Applied manually (not self-managed).

## Reach it

| Where | URL / address |
|---|---|
| Tailnet/LAN HTTP | http://argocd.homelab |
| In-cluster | argocd-server.infra.svc:80 (insecure backend) |

Not exposed publicly.

## Config

- Chart: `argo-cd` 7.8.23 (`charts/`), rendered by kustomize
- `values.yaml` — `server.ingress.hostname: argocd.homelab`, `server.insecure: true`
- Login: user `admin`, password from
  `kubectl get secret argocd-initial-admin-secret -n infra -o jsonpath='{.data.password}' | base64 -d`

## Apply

```bash
kustomize build --enable-helm k8s/platform/argocd/ | kubectl apply -f -
```
