#!/usr/bin/env bash
set -euo pipefail

# Run this from the repo root after Sealed Secrets is deployed.
# It encrypts .env into k8s/apps/blogs/sealed-secret.yaml, which you then
# commit and push — ArgoCD syncs it and the controller decrypts it into
# a real Secret named "blogs-env" in the apps namespace.
#
# Prerequisites:
#   - kubeseal installed (https://github.com/bitnami-labs/sealed-secrets/releases)
#   - sealed-secrets controller running in the cluster
#   - .env file in the repo root with your env vars

ENV_FILE=".env"
SECRET_NAME="blogs-env"
NAMESPACE="apps"
OUTPUT="k8s/apps/blogs/sealed-secret.yaml"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found in repo root"
  exit 1
fi

kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-env-file="$ENV_FILE" \
  --dry-run=client -o yaml \
  | kubeseal --controller-namespace infra --controller-name sealed-secrets \
    -o yaml > "$OUTPUT"

KUSTOMIZATION="k8s/apps/blogs/kustomization.yaml"
if grep -q "^  # - sealed-secret.yaml" "$KUSTOMIZATION"; then
  sed -i 's/^  # - sealed-secret.yaml/  - sealed-secret.yaml/' "$KUSTOMIZATION"
  echo "Updated $KUSTOMIZATION — uncommented sealed-secret.yaml resource"
fi

echo "Wrote $OUTPUT"
echo "Now run: git add $OUTPUT $KUSTOMIZATION && git commit -m 'add blogs SealedSecret' && git push"
