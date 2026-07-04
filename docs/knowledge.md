---
type: Architecture Reference
title: Homelab Knowledge Manual
description: Comprehensive reference covering k3s, ArgoCD, Kustomize, Helm, Traefik, cert-manager, DNS architecture, and cluster operations.
tags: [kubernetes, architecture, reference, homelab]
timestamp: 2026-07-04T00:00:00Z
---

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

`argocd-apps/root.yaml` is applied once manually. It watches the entire `argocd-apps/` folder — every `.yaml` file there is a managed ArgoCD Application.

```
kubectl apply -f argocd-apps/root.yaml   ← once, ever

root.yaml watches argocd-apps/
  ├── app-a.yaml    → syncs k8s/apps/app-a/
  └── app-b.yaml    → git push → auto deployed
```

Key behaviours:
- `selfHeal: true` — manual cluster changes get reverted to git state within ~3 min
- `prune: true` — delete a file from git, ArgoCD deletes the resource from the cluster
- polls every 3 minutes automatically, no manual sync needed

To add a new app, follow the [playbook](/add-app.md).

---

## Kustomize

Templating layer over raw k8s YAML. Used here to bundle Helm charts with custom values.

```yaml
helmCharts:
  - name: argo-cd
    repo: https://argoproj.github.io/argo-helm
    version: "7.8.23"
    valuesFile: values.yaml
```

```bash
kustomize build --enable-helm k8s/platform/argocd/                        # preview
kustomize build --enable-helm k8s/platform/argocd/ | kubectl apply -f -  # apply
```

`--enable-helm` is required when the kustomization references Helm charts.

---

## Helm

Package manager for k8s. Pre-built templates for common tools (ArgoCD, Traefik, Prometheus etc).

Not called directly — used through Kustomize. The `values.yaml` or `config.yaml` next to each `kustomization.yaml` is the Helm values override file for that chart.

---

## Traefik

Ingress controller. Routes external HTTP traffic to services by hostname.

```
browser → myapp.homelab
  → Traefik
    → matches Ingress rule host: myapp.homelab
      → forwards to myapp service:80
        → pod
```

Config lives in `k8s/platform/traefik/config.yaml`. Every Ingress resource needs `ingressClassName: traefik`.

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

## DNS Architecture

Three independent DNS paths:

### Tailnet devices (laptop, phone)
```
Browser → OS DNS (Tailscale 100.100.100.100)
  → Split DNS: *.homelab → 100.93.76.126
    → AdGuard (hostNetwork, port 53 on host)
      → DNS rewrite: *.homelab → 100.93.76.126
        → Returns 100.93.76.126
Browser connects to 100.93.76.126:80
  → Host port 80 → Traefik (via kube-proxy NodePort)
    → Ingress matches Host header → routes to service → pod
```

### Pods inside cluster
```
Container → CoreDNS (10.43.0.10) → NXDOMAIN for .homelab
```

### Host (Ubuntu)
```
Process → systemd-resolved (127.0.0.53) → upstream DNS (1.1.1.1)
```

No path depends on another — pods and the host resolve independently of AdGuard.

The full journey to this architecture (including failed attempts) is documented in [`docs/solved/internal-dns-with-adguard.md`](solved/internal-dns-with-adguard.md).

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
    - host: myapp.homelab
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

---

## Secrets

### Encryption at rest

k3s is started with `--secrets-encryption`, which enables symmetric encryption of Secret resources in etcd using an AES-CBC key. The encryption provider config and key are managed by k3s automatically. Verify with:

```bash
kubectl get secrets -A -o yaml | head -5     # data is ciphertext in etcd
sudo cat /var/lib/rancher/k3s/server/cred/encryption-config.json
```

This means raw Secret YAMLs are never committed to git — even if someone gets access to the etcd snapshot, they can't read secret values without the encryption key on the node. Locally, the `kubectl` API server decrypts them on read.

### App environment variables

This homelab uses plain Kubernetes Secrets for app env vars — no Sealed Secrets or External Secrets Operator. The workflow:

1. Keep a `.env` file locally (gitignored — see `.gitignore` rules)
2. Create a Secret from it:
   ```bash
   kubectl create secret generic <app>-env --from-env-file=.env -n <namespace>
   ```
3. Reference it in the Deployment via `envFrom`:
   ```yaml
   spec:
     containers:
       - envFrom:
           - secretRef:
               name: <app>-env
   ```
4. The `.env` file values must not have quotes around them — `--from-env-file` treats `"` as literal characters:
   ```bash
   # Correct
   DATABASE_URL=postgresql://user:pass@host:5432/db
   # Wrong — includes literal quotes
   DATABASE_URL="postgresql://user:pass@host:5432/db"
   ```

### DNS and inter-pod connectivity

Pods resolve each other via CoreDNS (10.43.0.10). The `.homelab` domain is **not** resolvable inside the cluster — it's only available on Tailnet devices via AdGuard (see [DNS Architecture](#dns-architecture)).

When one pod needs to reach another service, use the cluster-internal DNS name:

| Instead of | Use |
|---|---|
| `postgres.homelab` | `postgres.cloud` or `postgres.cloud.svc.cluster.local` |
| `minio.homelab` | `minio.cloud` or `minio.cloud.svc.cluster.local` |

Format: `<service-name>.<namespace>` — works for any service within the cluster.

### Pull secrets for private images

```bash
kubectl create secret docker-registry ghcr-secret \
  --namespace <namespace> \
  --docker-server=ghcr.io \
  --docker-username=<github-username> \
  --docker-password=<PAT with read:packages>
```

Add `imagePullSecrets` to the Deployment spec (see [Deployments](#deployments) above). Create once per namespace — the secret name is always `ghcr-secret`.
