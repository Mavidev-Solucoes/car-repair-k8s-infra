#!/usr/bin/env bash
set -euo pipefail

namespace="${1:?namespace is required}"
secret_name="${2:?secret name is required}"

if kubectl get secret "${secret_name}" -n "${namespace}" >/dev/null 2>&1; then
  printf '{"exists":"true"}\n'
  exit 0
fi

printf 'Required Kubernetes Secret %s/%s was not found. Run scripts/academy-sync-secrets.sh newrelic after creating the Academy base cluster and kubeconfig.\n' "${namespace}" "${secret_name}" >&2
exit 1
