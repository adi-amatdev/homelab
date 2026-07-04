---
type: Playbook
title: Adding a New Application
description: Step-by-step guide for deploying a new application to the homelab via the GitOps workflow.
tags: [argocd, gitops, kubernetes, deployment]
timestamp: 2026-07-04T00:00:00Z
---

# Adding a New App

3 steps. No `kubectl apply` needed.

The root [ArgoCD](/knowledge.md#argocd) app watches `argocd-apps/`. Drop a file there, push, it's deployed.

---

## 1. Copy the app template

```bash
cp templates/deployment.yaml k8s/apps/<your-app>/deployment.yaml
cp templates/service.yaml k8s/apps/<your-app>/service.yaml
cp templates/kustomization.yaml k8s/apps/<your-app>/kustomization.yaml
cp templates/namespace.yaml k8s/apps/<your-app>/namespace.yaml
```

Edit `deployment.yaml`:
```yaml
name: <your-app>
image: ghcr.io/<org>/<your-app>:latest
containerPort: <port>
```

Edit `service.yaml`:
```yaml
name: <your-app>
host: <your-app>.homelab
targetPort: <port>
```

`kustomization.yaml` already references both — no changes needed unless you add extra resources.

---

## 2. Register with ArgoCD

```bash
cp templates/argocd-app.yaml argocd-apps/apps/<your-app>.yaml
```

Edit the two fields:
```yaml
metadata:
  name: <your-app>
spec:
  source:
    path: k8s/apps/<your-app>
  destination:
    namespace: apps    # change if using a different namespace
```

---

## 3. Push

```bash
git add . && git commit -m "add <your-app>" && git push
```

ArgoCD syncs within ~3 minutes. Monitor at `http://argocd.homelab`.

### Pitfalls

- **`.gitignore` traps:** Patterns like `*-secrets.yaml` silently ignore new files. Run `git check-ignore <file>` to confirm a file is trackable.
- **Namespace ownership:** Only the first app in a namespace should include `namespace.yaml`. Additional apps omit it — ArgoCD's `CreateNamespace=true` handles creation.
- **Image name mismatch:** The GHCR repo name (`blog`) may differ from the k8s app name (`blogs`). Verify image tags exist at `https://ghcr.io/v2/<org>/<image>/tags/list` before deploying.
- **helmCharts in ArgoCD Apps:** Don't create ArgoCD Applications for kustomizations with `helmCharts`. Those are bootstrapped manually with `kustomize build --enable-helm | kubectl apply -f -`. See existing platform apps for the pattern.

---

## 4. Add environment variables

After the app is deployed, inject its env vars via a Kubernetes Secret. The app uses `--secrets-encryption` — secrets are encrypted at rest in etcd.

```bash
# 1. Create a .env file locally (gitignored — never commit it)
cat > .env << EOF
DATABASE_URL=postgresql://user:pass@<service>.<namespace>:5432/db
SOME_KEY=value
EOF

# 2. Create the Secret
kubectl create secret generic <app>-env --from-env-file=.env -n <namespace>

# 3. Add envFrom to your deployment.yaml and push
```

In the Deployment:
```yaml
spec:
  containers:
    - envFrom:
        - secretRef:
            name: <app>-env
```

**Important:** `.env` values must NOT have quotes around them (`KEY=value` not `KEY="value"`). The `--from-env-file` flag treats quotes as literal characters.

**DNS note:** Pods resolve each other via CoreDNS. The `.homelab` domain is unavailable inside the cluster — use `<service>.<namespace>` instead (see [Secrets → DNS](/knowledge.md#dns-and-inter-pod-connectivity) in the knowledge manual).

To update an existing app's env vars:
```bash
kubectl delete secret <app>-env -n <namespace>
kubectl create secret generic <app>-env --from-env-file=.env -n <namespace>
kubectl rollout restart deployment/<app> -n <namespace>
```

---

## Local DNS

Until Cloudflared is set up, add each app to `/etc/hosts` on any machine that needs to reach it:

```bash
echo "<traefik-lb-ip>  <your-app>.homelab" | sudo tee -a /etc/hosts
```

Get the [Traefik](/knowledge.md#traefik) LB IP:
```bash
kubectl get svc -n infra
```

---

## CI/CD for the app repo

The app repo needs a GitHub Actions workflow to build and push the image on every push to `main`. See `.github/workflows/build.yaml` in any existing app repo as a reference.

---

## Private image checklist

See [GHCR pull secrets](/knowledge.md#ghcr) for context.

- [ ] `ghcr-secret` exists in the target namespace
- [ ] `imagePullSecrets` is set in `deployment.yaml`
- [ ] GitHub Actions workflow pushes to `ghcr.io/<org>/<your-app>:latest`

```bash
# create pull secret (once per namespace)
kubectl create secret docker-registry ghcr-secret \
  --namespace <namespace> \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<PAT with read:packages>
```
