#!/usr/bin/env bash
# Build the sorter image into minikube's Docker daemon so the cluster can use
# it without an external registry.
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-flame-ai-sorter}"
IMAGE_TAG="${IMAGE_TAG:-0.1.0}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v minikube >/dev/null 2>&1; then
  echo "minikube not found on PATH" >&2
  exit 1
fi

if ! minikube status >/dev/null 2>&1; then
  echo "minikube is not running; start it first (minikube start)" >&2
  exit 1
fi

echo "Building ${IMAGE_NAME}:${IMAGE_TAG} into minikube's docker daemon..."
eval "$(minikube -p minikube docker-env)"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" "${ROOT_DIR}"
echo "Built ${IMAGE_NAME}:${IMAGE_TAG}"
