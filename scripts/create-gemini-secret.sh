#!/usr/bin/env bash
# Create or update the `gemini-llm-secrets` Secret used by the LiteLLM proxy.
# Reads GEMINI_API_KEY from the environment or a .env file in the project root;
# falls back to an interactive prompt.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAMESPACE="${OBSERVABILITY_NAMESPACE:-observability}"

if [ -z "${GEMINI_API_KEY:-}" ] && [ -f "${ROOT_DIR}/.env" ]; then
  # shellcheck disable=SC1090,SC1091
  set -a; . "${ROOT_DIR}/.env"; set +a
fi

if [ -z "${GEMINI_API_KEY:-}" ]; then
  if [ -t 0 ]; then
    read -rsp "GEMINI_API_KEY: " GEMINI_API_KEY
    echo
  else
    echo "GEMINI_API_KEY is not set and no TTY available for prompt" >&2
    exit 1
  fi
fi

if [ -z "${GEMINI_API_KEY}" ]; then
  echo "GEMINI_API_KEY is empty; aborting." >&2
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required" >&2
  exit 1
fi

kubectl get ns "${NAMESPACE}" >/dev/null 2>&1 || kubectl create ns "${NAMESPACE}"

kubectl create secret generic gemini-llm-secrets \
  --namespace "${NAMESPACE}" \
  --from-literal=GEMINI_API_KEY="${GEMINI_API_KEY}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Secret gemini-llm-secrets updated in namespace ${NAMESPACE}."
echo "Restart LiteLLM so it picks up the new key:"
echo "  kubectl rollout restart deploy/litellm -n ${NAMESPACE}"
