#!/usr/bin/env bash
# Copia as credenciais temporárias do AWS Academy para os secrets do GitHub Actions dos repositórios que fazem
# deploy no EKS. Rodar no começo de cada sessão do lab (as credenciais expiram quando a sessão termina).
#
# Antes: no AWS Academy, "AWS Details" > "AWS CLI" > copiar o bloco para ~/.aws/credentials (perfil default).
#
# Uso:
#   scripts/academy-github-credentials.sh            # só atualiza os secrets
#   scripts/academy-github-credentials.sh --deploy   # atualiza, sobe a plataforma e faz o deploy dos 4 serviços
#
# Os valores são lidos e enviados direto ao GitHub, sem aparecer na tela.
set -euo pipefail

ORG="${ORG:-Mavidev-Solucoes}"
PROFILE="${AWS_PROFILE:-default}"
PLATFORM_REPO="car-repair-k8s-infra"
SERVICE_REPOS=(car-repair-os-service car-repair-billing-service car-repair-production-service car-repair-saga-orchestrator)

read_credential() {
  aws configure get "$1" --profile "${PROFILE}"
}

access_key_id="$(read_credential aws_access_key_id)"
secret_access_key="$(read_credential aws_secret_access_key)"
session_token="$(read_credential aws_session_token)"

if [[ -z "${access_key_id}" || -z "${secret_access_key}" || -z "${session_token}" ]]; then
  echo "Credenciais incompletas no perfil ${PROFILE} de ~/.aws/credentials (precisa do aws_session_token do Academy)." >&2
  exit 1
fi

if ! aws sts get-caller-identity --profile "${PROFILE}" >/dev/null 2>&1; then
  echo "As credenciais do perfil ${PROFILE} não são válidas. A sessão do lab está ativa?" >&2
  exit 1
fi

for repo in "${PLATFORM_REPO}" "${SERVICE_REPOS[@]}"; do
  gh secret set AWS_ACCESS_KEY_ID --repo "${ORG}/${repo}" --body "${access_key_id}"
  gh secret set AWS_SECRET_ACCESS_KEY --repo "${ORG}/${repo}" --body "${secret_access_key}"
  gh secret set AWS_SESSION_TOKEN --repo "${ORG}/${repo}" --body "${session_token}"
  echo "Credenciais atualizadas em ${ORG}/${repo}."
done

if [[ "${1:-}" != "--deploy" ]]; then
  exit 0
fi

echo "Subindo a plataforma (workflow Platform)..."
gh workflow run platform.yml --repo "${ORG}/${PLATFORM_REPO}"
sleep 5
run_id="$(gh run list --repo "${ORG}/${PLATFORM_REPO}" --workflow platform.yml --limit 1 --json databaseId --jq '.[0].databaseId')"
gh run watch "${run_id}" --repo "${ORG}/${PLATFORM_REPO}" --exit-status

for repo in "${SERVICE_REPOS[@]}"; do
  gh workflow run cd.yml --repo "${ORG}/${repo}"
  echo "Deploy disparado em ${ORG}/${repo}."
done

echo "Acompanhe em: gh run list --workflow cd.yml --repo ${ORG}/<repositório>"
