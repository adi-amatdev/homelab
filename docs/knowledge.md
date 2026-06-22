# Knowledge Manual

How the pieces fit together in this homelab.

---

## k3s

Lightweight Kubernetes. Single-node. Installed with `--disable traefik` — Traefik is managed here via Helm instead.

Differences from full k8s: uses `containerd` directly, lighter footprint, built-in `local-path` storage provisioner.

---

## ArgoCD

Watches this git repo. Applies manifests to the cluster automatically. Git is always the source of truth.

### App of Apps

`argocd-apps/root.yaml` is applied once manually. It watches the entire `argocd-apps/` folder recursively — every `.yaml` file in any subdirectory is a managed ArgoCD Application.

```
kubectl apply -f argocd-apps/root.yaml   ← once, ever

root.yaml watches argocd-apps/
  ├── platform/
  │   ├── argocd.yaml   → manages ArgoCD itself via Helm (self-managing)
  │   └── traefik.yaml   → manages Traefik via Helm
  ├── apps/              → user apps (Deployment + Service + Ingress via Kustomize)
  └── cloud/             → cloud services (via Kustomize)
```

Key behaviours:
- `selfHeal: true` — manual cluster changes get reverted to git state within ~3 min
- `prune: true` — delete a file from git, ArgoCD deletes the resource from the cluster
- polls every 3 minutes automatically, no manual sync needed

### Self-managing platform

ArgoCD and Traefik are deployed **by ArgoCD itself** using native Helm support (multi-source: chart from Helm repo, values from this git repo). No Kustomize wrapper needed.

First-time bootstrap (only needed if the cluster is bare):

```bash
# 1. Install ArgoCD manually once (can't manage itself before it's running)
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd -n infra \
  --create-namespace -f platform/argocd/values.yaml

# 2. Bootstrap the root app — ArgoCD takes over everything
kubectl apply -f argocd-apps/root.yaml

# 3. (optional) Watch ArgoCD come up
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n infra
```

After step 2, ArgoCD manages itself, Traefik, and all apps. No more `kubectl apply`.

---

## Helm

Package manager for k8s. Pre-built templates for common tools (ArgoCD, Traefik, Prometheus etc).

Platform components (ArgoCD, Traefik) use native Helm via ArgoCD — the chart comes from the upstream Helm repo, and our custom values come from files in this repo.

---

## Traefik

Ingress controller. Routes external HTTP traffic to services by hostname.

```
browser → myapp.local
  → Traefik
    → matches Ingress rule host: myapp.local
      → forwards to myapp service:80
        → pod
```

Config lives in `platform/traefik/values.yaml`. Every Ingress resource needs `ingressClassName: traefik`.

ArgoCD is configured with `server.insecure: true` — TLS terminates at Traefik, not the app.

---

## cert-manager `🔜 not yet deployed`

Will automatically provision and renew TLS certs from Let's Encrypt. Once deployed, Ingress resources get HTTPS via a `cert-manager.io/cluster-issuer` annotation.

Two issuers planned: staging (testing, not browser-trusted) and prod (trusted, rate-limited).

---

## Cloudflared `🔜 not yet deployed`

Will expose local services to the internet without port forwarding. Creates an outbound tunnel from the cluster to Cloudflare's edge.

Once deployed, the `/etc/hosts` workaround for local DNS goes away — apps will be on a real public domain with TLS.

---

## Monitoring `🔜 not yet deployed`

Planned: `kube-prometheus-stack` Helm chart (Prometheus + Grafana + alerting) in the `monitoring` namespace.

---

## Deployments

Core k8s workload. Declares desired state — image, replicas, ports.

```yaml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    spec:
      imagePullSecrets:
        - name: ghcr-secret    # required for private registry images
      containers:
        - name: myapp
          image: ghcr.io/<org>/myapp:latest
          ports:
            - containerPort: 80
```

---

## Services

Stable internal DNS for pods. Pods are ephemeral — services give them a consistent cluster address.

```yaml
spec:
  selector:
    app: myapp
  ports:
    - port: 80
      targetPort: 80
```

Internal address: `http://myapp.<namespace>.svc.cluster.local`

---

## Ingress

Tells Traefik which hostname routes to which service.

```yaml
spec:
  ingressClassName: traefik
  rules:
    - host: myapp.$(DOMAIN)
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: myapp
                port:
                  number: 80
```

All app hostnames use `.local`. Edit each Ingress rule to change the domain later.

---

## GHCR

Docker images live here. GitHub Actions builds and pushes on every push to `main` using `GITHUB_TOKEN` — no manual secret needed on the GitHub side.

The cluster needs a pull secret to access private images:

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace <namespace> \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<PAT with read:packages>
```
