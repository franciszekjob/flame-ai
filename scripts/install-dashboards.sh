#!/usr/bin/env bash
# Wrap the dashboard JSON into a ConfigMap labelled grafana_dashboard=1 so the
# Grafana sidecar discovers and imports it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"
DASH_DIR="${ROOT_DIR}/grafana/dashboards"

if [ ! -d "${DASH_DIR}" ]; then
  echo "No dashboards directory at ${DASH_DIR}" >&2
  exit 1
fi

for json in "${DASH_DIR}"/*.json; do
  name="$(basename "${json}" .json)"
  cm_name="flame-ai-dashboard-${name}"
  echo "==> Installing dashboard ConfigMap ${cm_name}"
  kubectl create configmap "${cm_name}" \
    --namespace "${NAMESPACE}" \
    --from-file="${name}.json=${json}" \
    --dry-run=client -o yaml \
  | kubectl label --local -f - grafana_dashboard=1 -o yaml --dry-run=client \
  | kubectl apply -f -
done

echo "Done. Grafana sidecar will reload within ~30s."
