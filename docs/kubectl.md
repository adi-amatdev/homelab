# kubectl Quick Reference

---

## Pods

```bash
kubectl get pods -A                                   # all namespaces
kubectl get pods -n apps -w                           # watch
kubectl describe pod <pod> -n apps                    # events, state, image
kubectl logs <pod> -n apps                            # stdout
kubectl logs <pod> -n apps -f                         # follow
kubectl logs <pod> -n apps --previous                 # last crashed container
kubectl exec -it <pod> -n apps -- sh                  # shell into pod
```

---

## Deployments

```bash
kubectl get deployments -n apps
kubectl rollout restart deployment/<name> -n apps     # rolling restart
kubectl rollout status deployment/<name> -n apps      # watch rollout
kubectl rollout undo deployment/<name> -n apps        # rollback
```

---

## Ingress & Networking

```bash
kubectl get ingress -A                                # check HOST + ADDRESS
kubectl describe ingress <name> -n apps
kubectl get svc -A
```

---

## ArgoCD

> Apps live in `infra` namespace, not `argocd`.

```bash
kubectl get applications -n infra                     # list all apps
kubectl describe application <name> -n infra          # sync status + errors

# get admin password
kubectl get secret argocd-initial-admin-secret -n infra \
  -o jsonpath="{.data.password}" | base64 -d

# force sync (requires argocd CLI)
argocd app sync <name> --server argocd.local --insecure
```

---

## Secrets

```bash
kubectl get secrets -n apps
kubectl get secret <name> -n apps -o jsonpath="{.data.<key>}" | base64 -d
```

---

## Debugging

**ImagePullBackOff**
```bash
kubectl describe pod <pod> -n apps | grep -A 10 "Events:"
kubectl get secret ghcr-secret -n apps                # check pull secret exists
```

**CrashLoopBackOff**
```bash
kubectl logs <pod> -n apps --previous
kubectl describe pod <pod> -n apps
```

**Ingress not routing**
```bash
kubectl get ingress -A                                # confirm ADDRESS is set
kubectl describe ingress <name> -n apps              # check rules
kubectl get svc -n apps                              # confirm service exists
kubectl logs -n infra -l app.kubernetes.io/name=traefik  # traefik logs
```

**ArgoCD not syncing**
```bash
kubectl describe application <name> -n infra         # look at Conditions
kubectl get events -n infra --sort-by='.lastTimestamp'
```

---

## Namespaces

```bash
kubectl get namespaces
kubectl get all -n <namespace>
```

---

## Useful Flags

| Flag | Use |
|---|---|
| `-A` | all namespaces |
| `-w` | watch for changes |
| `-o wide` | more columns |
| `-o yaml` | full resource as YAML |
| `--previous` | last crashed container logs |
| `--sort-by='.lastTimestamp'` | sort events by time |
