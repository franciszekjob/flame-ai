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

# The grafana-plugins-provisioning ConfigMap must exist before the Grafana pod
# starts, because the values reference it as an extraConfigmapMounts entry.
echo "==> Rendering grafana-plugins-provisioning ConfigMap"
PROVISIONING_YAML="$(python3 - <<'PY'
import yaml, pathlib
values = yaml.safe_load(pathlib.Path("helm/values-grafana.yaml").read_text())
print(yaml.safe_dump(values.get("plugins_provisioning", {}), sort_keys=False))
PY
)"
kubectl create configmap grafana-plugins-provisioning \
  --namespace "${NAMESPACE}" \
  --from-literal=apps.yaml="${PROVISIONING_YAML}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing/upgrading Pyroscope"
helm upgrade --install pyroscope grafana/pyroscope \
  --namespace "${NAMESPACE}" \
  --values "${ROOT_DIR}/helm/values-pyroscope.yaml" \
  --wait --timeout 5m

echo "==> Ensuring grafana-llm-secrets exists (placeholder if user has not run create-openai-secret.sh)"
if ! kubectl get secret grafana-llm-secrets -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "    NOTE: no grafana-llm-secrets found. Creating placeholder with empty OPENAI_API_KEY."
  echo "    Run scripts/create-openai-secret.sh to install a real key."
  kubectl create secret generic grafana-llm-secrets \
    --namespace "${NAMESPACE}" \
    --from-literal=OPENAI_API_KEY=""
fi

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
