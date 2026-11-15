#!/usr/bin/env bash
# Sobe a plataforma e os quatro microsserviços num cluster kind, com os mesmos manifests do deploy no EKS,
# e roda o teste ponta a ponta da saga. Usado pelo workflow "E2E Kubernetes (kind)" e também roda local.
#
# Uso: scripts/kind-e2e.sh <pasta com os repositórios dos serviços>
#   A pasta deve conter car-repair-os-service, car-repair-billing-service,
#   car-repair-production-service e car-repair-saga-orchestrator.
# Variáveis: KIND_CLUSTER (padrão car-repair-e2e), KEEP_CLUSTER=true para não apagar o cluster no fim.
set -euo pipefail

SERVICES_DIR="$(cd "${1:?informe a pasta com os repositórios dos serviços}" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CLUSTER="${KIND_CLUSTER:-car-repair-e2e}"
NAMESPACE="car-repair"
IMAGE_TAG="e2e"
SERVICES=(car-repair-os-service car-repair-billing-service car-repair-production-service car-repair-saga-orchestrator)
PORTS=(5101 5102 5103 5104)
PORT_FORWARD_PIDS=()

cleanup() {
  for pid in ${PORT_FORWARD_PIDS[@]+"${PORT_FORWARD_PIDS[@]}"}; do
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
  done
  if [[ "${KEEP_CLUSTER:-false}" != "true" && "${CREATED_CLUSTER:-false}" == "true" ]]; then
    kind delete cluster --name "${KIND_CLUSTER}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

dump_diagnostics() {
  echo "::group::Diagnóstico do cluster"
  kubectl -n "${NAMESPACE}" get pods -o wide || true
  for service in "${SERVICES[@]}"; do
    echo "--- logs ${service}"
    kubectl -n "${NAMESPACE}" logs "deployment/${service}" --tail=80 || true
  done
  echo "::endgroup::"
}

if ! kind get clusters 2>/dev/null | grep -qx "${KIND_CLUSTER}"; then
  kind create cluster --name "${KIND_CLUSTER}" --wait 120s
  CREATED_CLUSTER=true
fi
kubectl config use-context "kind-${KIND_CLUSTER}"

for service in "${SERVICES[@]}"; do
  echo "Construindo ${service}..."
  docker build --quiet --file "${SERVICES_DIR}/${service}/src/Api/Dockerfile" \
    --tag "${service}:${IMAGE_TAG}" "${SERVICES_DIR}/${service}" >/dev/null
  kind load docker-image "${service}:${IMAGE_TAG}" --name "${KIND_CLUSTER}"
done

"${SCRIPT_DIR}/academy-bootstrap-platform.sh"

for service in "${SERVICES[@]}"; do
  kubectl kustomize "${SERVICES_DIR}/${service}/k8s/overlays/academy-dev" \
    | sed "s|image: ${service}:latest|image: ${service}:${IMAGE_TAG}|" \
    | kubectl apply -f -
done

for service in "${SERVICES[@]}"; do
  if ! kubectl -n "${NAMESPACE}" rollout status "deployment/${service}" --timeout=300s; then
    dump_diagnostics
    exit 1
  fi
done

for index in "${!SERVICES[@]}"; do
  kubectl -n "${NAMESPACE}" port-forward "svc/${SERVICES[$index]}" "${PORTS[$index]}:80" >/dev/null 2>&1 &
  PORT_FORWARD_PIDS+=("$!")
done
sleep 5

if ! OS_URL="http://localhost:5101" BILLING_URL="http://localhost:5102" \
  PRODUCTION_URL="http://localhost:5103" SAGA_URL="http://localhost:5104" \
  "${SCRIPT_DIR}/e2e-saga.sh"; then
  dump_diagnostics
  exit 1
fi
