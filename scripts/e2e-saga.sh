#!/usr/bin/env bash
# Teste ponta a ponta da saga com os quatro microsserviços no ar.
# Passa uma OS por cada cenário e confere o estado final em todos os serviços:
#   feliz      -> saga Completed, OS Closed,    orçamento Approved,  pagamento Approved
#   pagamento  -> saga Failed,    OS Cancelled, orçamento Cancelled, pagamento Rejected
#   execucao   -> saga Failed,    OS Cancelled, orçamento Cancelled, pagamento Refunded
#
# Uso: scripts/e2e-saga.sh [feliz|pagamento|execucao ...]   (sem argumentos roda os três)
# URLs: OS_URL, BILLING_URL, PRODUCTION_URL, SAGA_URL (padrão: localhost 5101 a 5104).
# Pelo Kong, todas podem apontar para o mesmo endereço (as rotas não se sobrepõem).
set -euo pipefail

OS_URL="${OS_URL:-http://localhost:5101}"
BILLING_URL="${BILLING_URL:-http://localhost:5102}"
PRODUCTION_URL="${PRODUCTION_URL:-http://localhost:5103}"
SAGA_URL="${SAGA_URL:-http://localhost:5104}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-60}"
USER_ID="11111111-1111-1111-1111-111111111111"

# Enums do billing (BudgetStatus e PaymentStatus) como chegam no JSON.
BUDGET_APPROVED=1
BUDGET_CANCELLED=3
PAYMENT_APPROVED=1
PAYMENT_REJECTED=2
PAYMENT_REFUNDED=3

fail() {
  echo "FALHOU: $*" >&2
  exit 1
}

request() {
  local method="$1" url="$2" body="${3:-}"
  local response status
  if [[ -n "${body}" ]]; then
    response="$(curl -sS -X "${method}" "${url}" -H 'Content-Type: application/json' -H "X-User-Id: ${USER_ID}" \
      -d "${body}" -w $'\n%{http_code}')"
  else
    response="$(curl -sS -X "${method}" "${url}" -H "X-User-Id: ${USER_ID}" -w $'\n%{http_code}')"
  fi
  status="${response##*$'\n'}"
  response="${response%$'\n'*}"
  [[ "${status}" =~ ^2 ]] || fail "${method} ${url} respondeu ${status}: ${response}"
  printf '%s' "${response}"
}

# Repete um comando até ele imprimir algo diferente de vazio/null.
wait_for() {
  local description="$1"
  shift
  local value=""
  for _ in $(seq 1 "${TIMEOUT_SECONDS}"); do
    value="$("$@" 2>/dev/null || true)"
    if [[ -n "${value}" && "${value}" != "null" ]]; then
      printf '%s' "${value}"
      return 0
    fi
    sleep 1
  done
  fail "tempo esgotado esperando ${description}"
}

saga_state() {
  curl -sf "${SAGA_URL}/api/sagas/$1" | jq -r '.currentState // empty'
}

wait_saga_state() {
  local service_order_id="$1" expected="$2" state=""
  for _ in $(seq 1 "${TIMEOUT_SECONDS}"); do
    state="$(saga_state "${service_order_id}" || true)"
    [[ "${state}" == "${expected}" ]] && { echo "  saga: ${state}"; return 0; }
    sleep 1
  done
  fail "saga da OS ${service_order_id} ficou em '${state}' (esperava ${expected})"
}

budget_for() {
  curl -sf "${BILLING_URL}/api/budgets" | jq -r --arg so "$1" '[.[] | select(.serviceOrderId == $so)][0].id // empty'
}

work_order_for() {
  curl -sf "${PRODUCTION_URL}/api/work-orders" | jq -r --arg so "$1" '[.[] | select(.serviceOrderId == $so)][0].id // empty'
}

open_service_order() {
  local suffix customer_id vehicle_id letters plate
  suffix="$(printf '%05d%06d' "${RANDOM}" "$((RANDOM * RANDOM % 1000000))")"
  letters="$(LC_ALL=C tr -dc 'A-Z' </dev/urandom | head -c 4)"
  plate="${letters:0:3}${suffix:0:1}${letters:3:1}${suffix:1:2}"

  customer_id="$(request POST "${OS_URL}/api/customers" "$(jq -nc --arg s "${suffix}" \
    '{name: ("Cliente E2E " + $s), personalId: $s, email: ("e2e" + $s + "@example.com"), telephone: "11988887777"}')" \
    | jq -r '.id')"
  vehicle_id="$(request POST "${OS_URL}/api/vehicles" "$(jq -nc --arg c "${customer_id}" --arg p "${plate}" \
    '{customerId: $c, brand: "Fiat", model: "Argo", year: 2022, licensePlate: $p, color: "Prata"}')" | jq -r '.id')"

  request POST "${OS_URL}/api/service-orders" "$(jq -nc --arg c "${customer_id}" --arg v "${vehicle_id}" \
    --arg i1 "$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)" --arg i2 "$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen)" \
    '{customerId: $c, vehicleId: $v, items: [
        {serviceItemId: $i1, description: "Troca de óleo", price: 150, quantity: 1},
        {serviceItemId: $i2, description: "Filtro de ar", price: 40, quantity: 2}]}')" | jq -r '.id'
}

os_status() {
  curl -sf "${OS_URL}/api/service-orders/$1" -H "X-User-Id: ${USER_ID}" | jq -r '.status // empty'
}

budget_status() {
  curl -sf "${BILLING_URL}/api/budgets" | jq -r --arg so "$1" '[.[] | select(.serviceOrderId == $so)][0].status // empty'
}

payment_status() {
  curl -sf "${BILLING_URL}/api/payments" | jq -r --arg so "$1" '[.[] | select(.serviceOrderId == $so)][0].status // empty'
}

# Os comandos finais da saga (fechar/cancelar OS, cancelar orçamento) são assíncronos: a saga já pode estar
# Completed/Failed enquanto os serviços ainda processam. Por isso cada estado é aguardado, não lido uma vez.
wait_status() {
  local description="$1" expected="$2" getter="$3" service_order_id="$4" actual=""
  for _ in $(seq 1 "${TIMEOUT_SECONDS}"); do
    actual="$("${getter}" "${service_order_id}" 2>/dev/null || true)"
    [[ "${actual}" == "${expected}" ]] && return 0
    sleep 1
  done
  fail "${description} da OS ${service_order_id} está '${actual}' (esperava ${expected})"
}

assert_final_state() {
  local service_order_id="$1" os_status="$2" budget_status="$3" payment_status="$4"

  wait_status "status" "${os_status}" os_status "${service_order_id}"
  wait_status "orçamento" "${budget_status}" budget_status "${service_order_id}"
  wait_status "pagamento" "${payment_status}" payment_status "${service_order_id}"

  echo "  OS ${os_status}, orçamento ${budget_status}, pagamento ${payment_status}"
}

run_scenario() {
  local scenario="$1" service_order_id budget_id work_order_id
  echo "== cenário ${scenario}"

  service_order_id="$(open_service_order)"
  echo "  OS ${service_order_id} aberta"
  wait_saga_state "${service_order_id}" WaitingBudgetApproval
  budget_id="$(wait_for "orçamento da OS" budget_for "${service_order_id}")"

  if [[ "${scenario}" == "pagamento" ]]; then
    request POST "${BILLING_URL}/api/budgets/${budget_id}/approve" '{"simulatePaymentFailure":true}' >/dev/null
    wait_saga_state "${service_order_id}" Failed
    assert_final_state "${service_order_id}" Cancelled "${BUDGET_CANCELLED}" "${PAYMENT_REJECTED}"
    return
  fi

  request POST "${BILLING_URL}/api/budgets/${budget_id}/approve" '{}' >/dev/null
  wait_saga_state "${service_order_id}" WaitingProduction
  work_order_id="$(wait_for "ordem de execução da OS" work_order_for "${service_order_id}")"
  request POST "${PRODUCTION_URL}/api/work-orders/${work_order_id}/start" >/dev/null

  if [[ "${scenario}" == "execucao" ]]; then
    request POST "${PRODUCTION_URL}/api/work-orders/${work_order_id}/fail" '{"reason":"Peça indisponível"}' >/dev/null
    wait_saga_state "${service_order_id}" Failed
    assert_final_state "${service_order_id}" Cancelled "${BUDGET_CANCELLED}" "${PAYMENT_REFUNDED}"
  else
    request POST "${PRODUCTION_URL}/api/work-orders/${work_order_id}/complete" >/dev/null
    wait_saga_state "${service_order_id}" Completed
    assert_final_state "${service_order_id}" Closed "${BUDGET_APPROVED}" "${PAYMENT_APPROVED}"
  fi
}

command -v jq >/dev/null || fail "jq não encontrado"
scenarios=("$@")
[[ ${#scenarios[@]} -gt 0 ]] || scenarios=(feliz pagamento execucao)

for scenario in "${scenarios[@]}"; do
  case "${scenario}" in
    feliz|pagamento|execucao) run_scenario "${scenario}" ;;
    *) fail "cenário desconhecido: ${scenario}" ;;
  esac
done

echo "OK: ${#scenarios[@]} cenário(s) da saga passaram."
