#!/usr/bin/env bash
# Install the Pyroscope + Grafana observability stack into minikube via Helm.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required but not installed" >&2
    exit 1
  fi
}

require helm
require kubectl

echo "==> Adding Helm repos"
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "==> Creating namespace ${NAMESPACE}"
kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

echo "==> Applying grafana-plugins-provisioning ConfigMap"
kubectl create configmap grafana-plugins-provisioning \
  --namespace "${NAMESPACE}" \
  --from-file=apps.yaml="${ROOT_DIR}/grafana/provisioning/apps.yaml" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing/upgrading Pyroscope"
helm upgrade --install pyroscope grafana/pyroscope \
  --namespace "${NAMESPACE}" \
  --values "${ROOT_DIR}/helm/values-pyroscope.yaml" \
  --wait --timeout 5m

echo "==> Ensuring grafana-llm-secrets exists (placeholder; real key is in gemini-llm-secrets)"
if ! kubectl get secret grafana-llm-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
  kubectl create secret generic grafana-llm-secrets \
    --namespace "${NAMESPACE}" \
    --from-literal=OPENAI_API_KEY="litellm"
fi

echo "==> Ensuring gemini-llm-secrets exists (run scripts/create-gemini-secret.sh to set real key)"
if ! kubectl get secret gemini-llm-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "    NOTE: no gemini-llm-secrets found. Creating placeholder with empty GEMINI_API_KEY."
  echo "    Run scripts/create-gemini-secret.sh to install your Gemini API key."
  kubectl create secret generic gemini-llm-secrets \
    --namespace "${NAMESPACE}" \
    --from-literal=GEMINI_API_KEY=""
fi

echo "==> Deploying LiteLLM proxy"
kubectl apply -f "${ROOT_DIR}/k8s/litellm/configmap.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/litellm/deployment.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/litellm/service.yaml"

echo "==> Installing/upgrading Grafana"
helm upgrade --install grafana grafana/grafana \
  --namespace "${NAMESPACE}" \
  --values "${ROOT_DIR}/helm/values-grafana.yaml" \
  --wait --timeout 5m

echo ""
echo "Observability stack installed in namespace '${NAMESPACE}'."
echo "Port-forward Grafana:"
echo "  kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:80"
echo "Then open http://localhost:3000 (admin / admin)."
