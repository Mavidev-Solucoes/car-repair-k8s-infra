#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage:
  scripts/academy-sync-secrets.sh newrelic

Environment overrides:
  AWS_REGION                    AWS region. Default: us-east-1
  ACADEMY_NEWRELIC_SECRET_ID    Secrets Manager secret id. Default: car-repair/dev/newrelic
  ACADEMY_NEWRELIC_NAMESPACE    Kubernetes namespace. Default: newrelic
  ACADEMY_NEWRELIC_K8S_SECRET   Kubernetes Secret name. Default: newrelic-license
  ACADEMY_NEWRELIC_SECRET_KEY   Secrets Manager JSON property and Kubernetes Secret key. Default: licenseKey

This script is only the AWS Academy fallback. Normal AWS environments use:
  Secrets Manager -> External Secrets Operator -> Kubernetes Secret
USAGE
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$1" >&2
    exit 1
  fi
}

extract_json_property() {
  local json="$1"
  local property="$2"

  jq -er --arg property "$property" '.[$property] // empty' <<<"$json"
}

sync_json_secret_property() {
  local secret_id="$1"
  local namespace="$2"
  local kubernetes_secret="$3"
  local property="$4"
  local kubernetes_key="$5"

  local secret_string
  local secret_value

  secret_string="$(
    aws secretsmanager get-secret-value \
      --secret-id "$secret_id" \
      --query SecretString \
      --output text
  )"

  if [[ -z "$secret_string" || "$secret_string" == "None" ]]; then
    printf 'Secrets Manager secret %s has no SecretString value.\n' "$secret_id" >&2
    exit 1
  fi

  secret_value="$(extract_json_property "$secret_string" "$property")"

  if [[ -z "$secret_value" ]]; then
    printf 'Property %s was not found in Secrets Manager secret %s.\n' "$property" "$secret_id" >&2
    exit 1
  fi

  kubectl create namespace "$namespace" \
    --dry-run=client \
    -o yaml |
    kubectl apply -f -

  kubectl create secret generic "$kubernetes_secret" \
    --namespace "$namespace" \
    --from-literal="${kubernetes_key}=${secret_value}" \
    --dry-run=client \
    -o yaml |
    kubectl apply -f -
}

sync_newrelic() {
  local secret_id="${ACADEMY_NEWRELIC_SECRET_ID:-car-repair/dev/newrelic}"
  local namespace="${ACADEMY_NEWRELIC_NAMESPACE:-newrelic}"
  local kubernetes_secret="${ACADEMY_NEWRELIC_K8S_SECRET:-newrelic-license}"
  local secret_key="${ACADEMY_NEWRELIC_SECRET_KEY:-licenseKey}"

  sync_json_secret_property "$secret_id" "$namespace" "$kubernetes_secret" "$secret_key" "$secret_key"
}

main() {
  if [[ $# -ne 1 ]]; then
    usage
    exit 1
  fi

  export AWS_REGION="${AWS_REGION:-us-east-1}"

  require_command aws
  require_command kubectl
  require_command jq

  case "$1" in
    newrelic)
      sync_newrelic
      ;;
    database | jwt | smtp)
      printf 'Secret sync target %s is reserved for a future mapping. No hardcoded values are implemented.\n' "$1" >&2
      exit 1
      ;;
    -h | --help | help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
