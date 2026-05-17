#!/usr/bin/env bash
# Create or update the `grafana-llm-secrets` Secret used by Grafana's
# grafana-llm-app plugin. Reads the API key from $OPENAI_API_KEY or a .env file
# in the project root; falls back to interactive prompt.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"
SECRET_NAME="${SECRET_NAME:-grafana-llm-secrets}"

if [ -z "${OPENAI_API_KEY:-}" ] && [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1090,SC1091
  set -a; . "${ROOT_DIR}/.env"; set +a
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  if [ -t 0 ]; then
    read -rsp "OPENAI_API_KEY: " OPENAI_API_KEY
    echo
  else
    echo "OPENAI_API_KEY is not set and no TTY available for prompt" >&2
    exit 1
  fi
fi

if [ -z "${OPENAI_API_KEY}" ]; then
  echo "OPENAI_API_KEY is empty; aborting." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=OPENAI_API_KEY="${OPENAI_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret ${SECRET_NAME} updated in namespace ${NAMESPACE}."
echo "Restart Grafana so it picks up the new key:"
echo "  kubectl rollout restart deploy/grafana -n ${NAMESPACE}"
