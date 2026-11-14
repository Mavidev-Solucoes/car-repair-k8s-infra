#!/usr/bin/env bash
# Sobe as dependências dos microsserviços (Postgres por serviço, MongoDB e RabbitMQ) no namespace car-repair.
# As senhas são geradas aqui, uma vez por cluster, e ficam só em Secrets do Kubernetes: nada vai para o git.
# Rodar de novo é seguro: Secrets existentes são mantidos e o kubectl apply só aplica diferenças.
#
# Uso: scripts/academy-bootstrap-platform.sh
set -euo pipefail

NAMESPACE="${NAMESPACE:-car-repair}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_DIR="${SCRIPT_DIR}/../platform"

random_password() {
  openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 32
}

ensure_secret() {
  local name="$1"
  shift

  if kubectl -n "${NAMESPACE}" get secret "${name}" >/dev/null 2>&1; then
    echo "Secret ${name} já existe; mantendo."
    return
  fi

  kubectl -n "${NAMESPACE}" create secret generic "${name}" "$@"
  echo "Secret ${name} criado."
}

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

for service in os billing saga; do
  ensure_secret "${service}-postgres" --from-literal=password="$(random_password)"
done

ensure_secret production-mongodb \
  --from-literal=username=production \
  --from-literal=password="$(random_password)"

ensure_secret rabbitmq \
  --from-literal=username=car-repair \
  --from-literal=password="$(random_password)"

kubectl apply -k "${PLATFORM_DIR}"

for statefulset in rabbitmq production-mongodb os-postgres billing-postgres saga-postgres; do
  kubectl -n "${NAMESPACE}" rollout status "statefulset/${statefulset}" --timeout=300s
done

echo "Plataforma pronta no namespace ${NAMESPACE}."
