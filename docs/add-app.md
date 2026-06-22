# Adding a New App

3 steps. No `kubectl apply` needed.

The root ArgoCD app watches `argocd-apps/`. Drop a file there, push, it's deployed.

---

## 1. Copy the app template

```bash
cp templates/deployment.yaml apps/<your-app>/deployment.yaml
cp templates/service.yaml apps/<your-app>/service.yaml
cp templates/kustomization.yaml apps/<your-app>/kustomization.yaml
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
host: <your-app>.$(DOMAIN)
targetPort: <port>
```

`kustomization.yaml` already includes `../../config` and defines the `$(DOMAIN)` variable — no changes needed unless you add extra resources.

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
    path: apps/<your-app>
  destination:
    namespace: apps    # change if using a different namespace
```

No need to create a Namespace resource — `CreateNamespace=true` in the Application handles it.

---

## 3. Push

```bash
git add . && git commit -m "add <your-app>" && git push
```

ArgoCD syncs within ~3 minutes. Monitor at `http://argocd.local`.

---

## Local DNS

Until Cloudflared is set up, add each app to `/etc/hosts` on any machine that needs to reach it:

```bash
echo "<traefik-lb-ip>  <your-app>.local" | sudo tee -a /etc/hosts
```

Get the Traefik LB IP:
```bash
kubectl get svc -n infra
```

---

## CI/CD for the app repo

The app repo needs a GitHub Actions workflow to build and push the image on every push to `main`. See `.github/workflows/build.yaml` in any existing app repo as a reference.

---

## Private image checklist

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

---

## Changing the domain

All Kustomize-managed apps use `$(DOMAIN)` resolved from `config/domain` (currently `local`). To switch domains:

1. Edit `config/domain` (e.g., `local` → `mydomain.com`)
2. Update `platform/traefik/values.yaml` and `platform/argocd/values.yaml` — these use hardcoded hostnames since Helm values aren't templated
3. Commit and push — ArgoCD syncs everything
