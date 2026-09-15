locals {
  newrelic_observability_enabled = var.enable_newrelic_observability_resources
  newrelic_app_name              = coalesce(var.newrelic_app_name, "car-repair-app-${var.environment}")
  newrelic_business_environment  = coalesce(var.business_environment, var.environment == "prod" ? "Production" : "Development")
  car_repair_app_namespace       = "car-repair-app"
  car_repair_app_deployment      = "car-repair-app"
  kong_troubleshooting_namespace = var.kong_namespace

  newrelic_apm_latency_p95_query       = "FROM Transaction SELECT percentile(duration, 95) WHERE appName = '${local.newrelic_app_name}' TIMESERIES"
  newrelic_apm_throughput_query        = "FROM Transaction SELECT rate(count(*), 1 minute) WHERE appName = '${local.newrelic_app_name}' TIMESERIES"
  newrelic_apm_error_rate_query        = "FROM Transaction SELECT percentage(count(*), WHERE error IS true) WHERE appName = '${local.newrelic_app_name}' TIMESERIES"
  newrelic_apm_success_rate_query      = "FROM Transaction SELECT percentage(count(*), WHERE error IS NOT true) WHERE appName = '${local.newrelic_app_name}' TIMESERIES"
  newrelic_orders_per_day_query        = "FROM CarRepairServiceOrderCreated SELECT count(*) WHERE Environment = '${local.newrelic_business_environment}' TIMESERIES 1 day"
  newrelic_duration_by_status_query    = "FROM CarRepairServiceOrderStatusChanged SELECT average(DurationSeconds) / 60 WHERE Environment = '${local.newrelic_business_environment}' FACET PreviousStatus"
  newrelic_transitions_by_status_query = "FROM CarRepairServiceOrderStatusChanged SELECT count(*) WHERE Environment = '${local.newrelic_business_environment}' FACET NewStatus"
  newrelic_pods_query                  = "FROM K8sPodSample SELECT uniqueCount(podName) WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}' FACET status TIMESERIES"
  newrelic_container_restarts_query    = "FROM K8sContainerSample SELECT max(restartCount) - min(restartCount) WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}' TIMESERIES"
  newrelic_cpu_query                   = "FROM K8sContainerSample SELECT sum(cpuUsedCores) WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}' TIMESERIES"
  newrelic_memory_query                = "FROM K8sContainerSample SELECT sum(memoryUsedBytes) / 1024 / 1024 WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}' TIMESERIES"
  newrelic_deployment_health_query     = "FROM K8sDeploymentSample SELECT latest(podsDesired), latest(podsAvailable), latest(podsUnavailable) WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}' TIMESERIES"
  newrelic_hpa_query                   = "FROM K8sHpaSample SELECT latest(currentReplicas), latest(desiredReplicas), latest(minReplicas), latest(maxReplicas) WHERE namespaceName = '${local.car_repair_app_namespace}' TIMESERIES"
  newrelic_kong_pods_query             = "FROM K8sPodSample SELECT uniqueCount(podName) WHERE namespaceName = '${local.kong_troubleshooting_namespace}' FACET status TIMESERIES"

  newrelic_alert_error_rate_query    = "SELECT percentage(count(*), WHERE error IS true) FROM Transaction WHERE appName = '${local.newrelic_app_name}'"
  newrelic_alert_latency_p95_query   = "SELECT percentile(duration, 95) FROM Transaction WHERE appName = '${local.newrelic_app_name}'"
  newrelic_alert_availability_query  = "SELECT latest(podsAvailable) FROM K8sDeploymentSample WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}'"
  newrelic_alert_restarts_query      = "SELECT max(restartCount) - min(restartCount) FROM K8sContainerSample WHERE namespaceName = '${local.car_repair_app_namespace}' AND deploymentName = '${local.car_repair_app_deployment}'"
  newrelic_kubernetes_loss_of_signal = var.environment == "prod"
}

resource "newrelic_one_dashboard" "car_repair_shop" {
  count = local.newrelic_observability_enabled ? 1 : 0

  account_id  = var.newrelic_account_id
  name        = "Car Repair Shop - ${var.environment}"
  description = "APM, business, and Kubernetes observability for ${local.newrelic_app_name}."
  permissions = var.newrelic_dashboard_permissions

  page {
    name        = "API / APM"
    description = "Golden signals for the .NET API using Transaction events filtered by appName."

    widget_line {
      title  = "Latency p95"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_apm_latency_p95_query
      }
    }

    widget_line {
      title  = "Throughput"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_apm_throughput_query
      }
    }

    widget_line {
      title  = "Error rate"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_apm_error_rate_query
      }
    }

    widget_line {
      title  = "Success rate"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_apm_success_rate_query
      }
    }
  }

  page {
    name        = "Negocio"
    description = "Business telemetry emitted by car-repair-app custom events."

    widget_line {
      title  = "Ordens de servico por dia"
      row    = 1
      column = 1
      width  = 12
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_orders_per_day_query
      }
    }

    widget_bar {
      title  = "Tempo medio por status (min)"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_duration_by_status_query
      }
    }

    widget_bar {
      title  = "Transicoes por status"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_transitions_by_status_query
      }
    }
  }

  page {
    name        = "Kubernetes"
    description = "Kubernetes integration data for the app namespace and Kong troubleshooting."

    widget_line {
      title  = "Pods da aplicacao"
      row    = 1
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_pods_query
      }
    }

    widget_line {
      title  = "Container restarts"
      row    = 1
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_container_restarts_query
      }
    }

    widget_line {
      title  = "CPU cores usados"
      row    = 4
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_cpu_query
      }
    }

    widget_line {
      title  = "Memoria usada (MiB)"
      row    = 4
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_memory_query
      }
    }

    widget_line {
      title  = "Deployment health"
      row    = 7
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_deployment_health_query
      }
    }

    widget_line {
      title  = "HPA replicas"
      row    = 7
      column = 7
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_hpa_query
      }
    }

    widget_line {
      title  = "Kong pods"
      row    = 10
      column = 1
      width  = 6
      height = 3

      nrql_query {
        account_id = var.newrelic_account_id
        query      = local.newrelic_kong_pods_query
      }
    }
  }
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
