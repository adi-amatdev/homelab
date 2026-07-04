---
type: Lessons Learned
title: Homelab Lessons Learned
description: Hard-earned operational lessons from the June 2026 restructure incident, covering pruning, Kustomize, platform changes, and incrementalism.
tags: [homelab, lessons, kubernetes, operations]
timestamp: 2026-07-04T00:00:00Z
---

# Lessons Learned

Mistakes made during the [2026-06-22 restructure](/history.md#phase-2-the-great-restructure-june-22), documented so they don't happen again.

---

## 1. `prune: true` deletes namespaces and everything in them

ArgoCD Applications here have `prune: true`. Deleting `namespace.yaml` from an app directory causes ArgoCD to **delete the entire namespace** — including all secrets, pods, and services inside it.

**Lesson:** Never remove a `namespace.yaml` from a directory managed by a prunning Application without first migrating secrets to a different namespace or using a namespace-scoped resource that won't be affected.

---

## 2. Test Kustomize variable substitution in the actual ArgoCD environment

`kustomize build` worked locally and showed correct substitution, but ArgoCD may use a different Kustomize version or have different path resolution. The `$(DOMAIN)` approach via `vars` was fragile and its failure was only discovered after deployment.

**Lesson:** Any transformation that depends on Kustomize build-time features (`vars`, `replacements`, path-dependent resources) must be tested end-to-end through ArgoCD before pushing to main.

---

## 3. Don't change the deployment mechanism of platform components mid-stream

Switching Traefik and ArgoCD from the working Kustomize-helmCharts pattern to ArgoCD-native Helm (multi-source) introduced a new failure mode. If the Helm release fails or the Application definition is wrong, the ingress controller or GitOps engine itself goes down — cascading failure.

**Lesson:** Platform infrastructure (ingress controller, GitOps engine) should be treated as critical path. Changes to how they're deployed should be made in isolation, not as part of a broader restructure. Test on a non-production cluster first or stage the change separately.

---

## 4. One thing at a time

This session bundled four changes at once:
- Removed namespace.yaml from all apps
- Replaced Kustomize helmCharts with native Helm for platform
- Moved argocd-apps from platform/ to root
- Added domain parameterization

When something broke, it was impossible to tell which change caused it.

**Lesson:** Each structural change should be its own commit. Deploy and verify each one before moving to the next. Batch changes only when you're certain none can break the cluster.

---

## 5. `.homelab` is fine. Parameterization can wait.

Hardcoding `.homelab` is simple, readable, and works. Domain parameterization adds complexity with no immediate benefit. Premature abstraction introduced a fragile `vars`/`config` dependency that broke in production.

**Lesson:** Don't parameterize until the parameter actually needs to change. When it does, use a mechanism you understand end-to-end and test before deploying.

---

## 6. `.gitignore` silently eats new files

Patterns like `*-secrets.yaml` in `.gitignore` will silently ignore any new file matching the pattern — including `sealed-secrets.yaml`. No warning, no error, the file just never gets committed. ArgoCD then fails because it can't find the file in the repo.

**Lesson:** After creating any new file in the repo, run `git check-ignore <file>` to confirm it's trackable. Use `git status --short` to verify new files show as `??` (untracked) before adding them.

---

## 7. Two ArgoCD apps can't own the same namespace

Each ArgoCD Application labels resources it manages with `argocd.argoproj.io/instance: <app-name>`. When two apps both include the same `namespace.yaml`, they fight over the labels — ArgoCD's `selfHeal` makes them revert each other's labels indefinitely.

**Lesson:** Only one app should declare `namespace.yaml` for a shared namespace. Additional apps in the same namespace should rely on ArgoCD's `CreateNamespace=true` sync option and omit `namespace.yaml` from their kustomization. Alternatively, move the namespace to a dedicated platform app that owns it once.

---

## 8. Platform components with helmCharts need manual bootstrapping

ArgoCD Applications using Kustomize with `helmCharts` require `--enable-helm` to render. The Application spec's `kustomize.enableHelm` field isn't accepted by all ArgoCD CRD versions. The existing platform components (argocd, traefik) were bootstrapped manually with `kustomize build --enable-helm | kubectl apply -f -` and don't have ArgoCD Application entries for this reason.

**Lesson:** Don't create ArgoCD Applications for kustomizations that use `helmCharts` unless you've verified the CRD supports `kustomize.enableHelm` or you configure it via `argocd-cm`. For platform components, keep the manual bootstrap pattern.

---

## 9. Verify image names against GHCR before deploying

The GitHub Container Registry repo name may differ from the k8s app name. Deploying with `ghcr.io/<org>/blogs` when the image was pushed to `ghcr.io/<org>/blog` causes `ErrImagePull` with no obvious hints. The image tag (`latest` vs SHA) must also exist.

**Lesson:** Before deploying, verify the image exists:
```bash
curl -s "https://ghcr.io/v2/<org>/<image>/tags/list" | jq
```
Or check the GHCR web UI. Match both the repo name and tag to what the CI actually pushes.
