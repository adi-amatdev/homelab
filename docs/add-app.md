# Adding a New App

3 steps. No `kubectl apply` needed.

The root ArgoCD app watches `platform/argocd-apps/`. Drop a file there, push, it's deployed.

---

## 1. Copy the app template

```bash
cp templates/deployment.yaml apps/<your-app>/deployment.yaml
cp templates/service.yaml apps/<your-app>/service.yaml
cp templates/kustomization.yaml apps/<your-app>/kustomization.yaml
cp templates/namespace.yaml apps/<your-app>/namespace.yaml
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
host: <your-app>.local
targetPort: <port>
```

`kustomization.yaml` already references both — no changes needed unless you add extra resources.

---

## 2. Register with ArgoCD

```bash
cp templates/argocd-app.yaml platform/argocd-apps/apps/<your-app>.yaml
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
