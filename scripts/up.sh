#!/usr/bin/env bash
# Bring the whole flame-ai demo up from zero.
#   1. minikube start (if not already running)
#   2. Build sorter image into minikube's docker
#   3. Apply sorter manifests
#   4. Install/refresh Pyroscope + Grafana via Helm
#   5. Install dashboard ConfigMap
#   6. Optional: apply k6 TestRun (set RUN_K6=1)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAMESPACE="${APP_NAMESPACE:-flame-ai}"
OBS_NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-6g}"
RUN_K6="${RUN_K6:-0}"

cd "${ROOT_DIR}"

echo "==> Ensuring minikube is running"
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus="${MINIKUBE_CPUS}" --memory="${MINIKUBE_MEMORY}"
fi

echo "==> Building sorter image inside minikube"
"${ROOT_DIR}/scripts/build-image.sh"

echo "==> Applying sorter manifests"
kubectl apply -f "${ROOT_DIR}/k8s/sorter/namespace.yaml"
kubectl apply -f "${ROOT_DIR}/k8s/sorter/"

echo "==> Installing observability stack"
OBSERVABILITY_NAMESPACE="${OBS_NAMESPACE}" "${ROOT_DIR}/scripts/install-stack.sh"

echo "==> Installing dashboards"
OBSERVABILITY_NAMESPACE="${OBS_NAMESPACE}" "${ROOT_DIR}/scripts/install-dashboards.sh"

echo "==> Waiting for sorter rollout"
kubectl rollout status deploy/sorter -n "${APP_NAMESPACE}" --timeout=2m

if [ "${RUN_K6}" = "1" ]; then
  echo "==> Applying k6 TestRun"
  kubectl apply -f "${ROOT_DIR}/k6/k8s/configmap.yaml"
  kubectl apply -f "${ROOT_DIR}/k6/k8s/testrun.yaml"
fi

cat <<EOF

Demo is up.

Grafana:    kubectl port-forward -n ${OBS_NAMESPACE} svc/grafana 3000:80
            -> http://localhost:3000  (admin / admin)

Pyroscope:  kubectl port-forward -n ${OBS_NAMESPACE} svc/pyroscope 4040:4040
            -> http://localhost:4040

Sorter:     kubectl port-forward -n ${APP_NAMESPACE} svc/sorter 8080:80
            -> http://localhost:8080/slow?n=5000

To drive load locally:
  BASE_URL=http://localhost:8080 k6 run k6/scenarios/slow-flood.js

EOF
