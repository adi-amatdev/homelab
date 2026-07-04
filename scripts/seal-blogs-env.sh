#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"

ENV_FILE=".env"
SECRET_NAME="blogs-env"
NAMESPACE="apps"
OUTPUT="k8s/apps/blogs/sealed-secret.yaml"

[ -f "$ENV_FILE" ] || { echo "Error: $ENV_FILE not found"; exit 1; }

kubectl create secret generic "$SECRET_NAME" \
  --namespace "$NAMESPACE" \
  --from-env-file="$ENV_FILE" \
  --dry-run=client -o yaml \
  | kubeseal --controller-namespace infra --controller-name sealed-secrets \
    -o yaml > "$OUTPUT"

KUSTOMIZATION="k8s/apps/blogs/kustomization.yaml"
sed -i 's/^  # - sealed-secret.yaml/  - sealed-secret.yaml/' "$KUSTOMIZATION"

echo "Wrote $OUTPUT — commit both files"
