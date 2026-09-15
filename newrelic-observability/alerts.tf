locals {
  newrelic_alert_error_rate_query    = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${local.newrelic_app_name}'"
  newrelic_alert_latency_p95_query   = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = '${local.newrelic_app_name}'"
  newrelic_alert_availability_query  = "SELECT latest(podsAvailable) FROM K8sDeploymentSample WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}'"
  newrelic_alert_restarts_query      = "SELECT max(restartCount) - min(restartCount) FROM K8sContainerSample WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}'"
  newrelic_kubernetes_loss_of_signal = var.environment == "prod"
}

resource "newrelic_alert_policy" "car_repair_shop" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id          = var.newrelic_account_id
  name                = "car-repair-shop-${var.environment}"
  incident_preference = var.newrelic_alert_incident_preference
}

resource "newrelic_nrql_alert_condition" "api_error_rate" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.car_repair_shop[0].id
  type                         = "static"
  name                         = "API error rate - ${local.newrelic_app_name}"
  description                  = "Transaction error rate for ${local.newrelic_app_name}."
  enabled                      = true
  violation_time_limit_seconds = 3600
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = local.newrelic_alert_error_rate_query
  }

  warning {
    operator              = "above"
    threshold             = var.newrelic_error_rate_warning_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  critical {
    operator              = "above"
    threshold             = var.newrelic_error_rate_critical_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "api_latency_p95" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id                   = var.newrelic_account_id
  policy_id                    = newrelic_alert_policy.car_repair_shop[0].id
  type                         = "static"
  name                         = "API p95 latency - ${local.newrelic_app_name}"
  description                  = "p95 Transaction duration for ${local.newrelic_app_name}."
  enabled                      = true
  violation_time_limit_seconds = 3600
  aggregation_window           = 60
  aggregation_method           = "event_flow"
  aggregation_delay            = 120

  nrql {
    query = local.newrelic_alert_latency_p95_query
  }

  warning {
    operator              = "above"
    threshold             = var.newrelic_latency_p95_warning_seconds
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  critical {
    operator              = "above"
    threshold             = var.newrelic_latency_p95_critical_seconds
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "deployment_availability" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.car_repair_shop[0].id
  type                           = "static"
  name                           = "Deployment availability - ${local.car_repair_app_deployment}"
  description                    = "Available replicas for the car-repair-app Kubernetes deployment."
  enabled                        = true
  violation_time_limit_seconds   = 3600
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = local.newrelic_kubernetes_loss_of_signal ? var.newrelic_loss_of_signal_expiration_seconds : null
  open_violation_on_expiration   = local.newrelic_kubernetes_loss_of_signal
  close_violations_on_expiration = local.newrelic_kubernetes_loss_of_signal

  nrql {
    query = local.newrelic_alert_availability_query
  }

  warning {
    operator              = "below"
    threshold             = var.newrelic_available_replicas_warning_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  critical {
    operator              = "below"
    threshold             = var.newrelic_available_replicas_critical_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}

resource "newrelic_nrql_alert_condition" "container_restarts" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id                     = var.newrelic_account_id
  policy_id                      = newrelic_alert_policy.car_repair_shop[0].id
  type                           = "static"
  name                           = "Container restarts - ${local.car_repair_app_deployment}"
  description                    = "Container restart delta for the car-repair-app Kubernetes deployment."
  enabled                        = true
  violation_time_limit_seconds   = 3600
  fill_option                    = "static"
  fill_value                     = 0
  aggregation_window             = 60
  aggregation_method             = "event_flow"
  aggregation_delay              = 120
  expiration_duration            = local.newrelic_kubernetes_loss_of_signal ? var.newrelic_loss_of_signal_expiration_seconds : null
  open_violation_on_expiration   = local.newrelic_kubernetes_loss_of_signal
  close_violations_on_expiration = local.newrelic_kubernetes_loss_of_signal

  nrql {
    query = local.newrelic_alert_restarts_query
  }

  warning {
    operator              = "above"
    threshold             = var.newrelic_restart_warning_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }

  critical {
    operator              = "above"
    threshold             = var.newrelic_restart_critical_threshold
    threshold_duration    = 300
    threshold_occurrences = "ALL"
  }
}
