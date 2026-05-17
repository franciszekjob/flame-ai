#!/usr/bin/env bash
# Tear the demo down. By default keeps the minikube cluster (faster next `up`).
# Pass --purge to also delete the cluster.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAMESPACE="${APP_NAMESPACE:-flame-ai}"
OBS_NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"
PURGE=0

for arg in "$@"; do
  case "${arg}" in
    --purge) PURGE=1 ;;
    *) echo "unknown arg: ${arg}" >&2; exit 1 ;;
  esac
done

if ! minikube status >/dev/null 2>&1; then
  echo "minikube is not running; nothing to tear down."
  exit 0
fi

echo "==> Deleting k6 TestRun (if present)"
kubectl delete -f "${ROOT_DIR}/k6/k8s/testrun.yaml" --ignore-not-found

echo "==> Uninstalling Helm releases"
helm uninstall grafana   -n "${OBS_NAMESPACE}" 2>/dev/null || true
helm uninstall pyroscope -n "${OBS_NAMESPACE}" 2>/dev/null || true

echo "==> Deleting namespaces"
kubectl delete ns "${APP_NAMESPACE}" --ignore-not-found
kubectl delete ns "${OBS_NAMESPACE}" --ignore-not-found

if [ "${PURGE}" = "1" ]; then
  echo "==> Deleting minikube cluster"
  minikube delete
fi

echo "Done."
