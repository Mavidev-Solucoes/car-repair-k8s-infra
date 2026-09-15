variable "enable_newrelic_observability_resources" {
  description = "Whether to create New Relic dashboards and alert conditions."
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name used in New Relic resource names."
  type        = string

  validation {
    condition     = contains(["dev", "prod", "academy-dev"], var.environment)
    error_message = "environment must be dev, prod, or academy-dev."
  }
}

variable "newrelic_account_id" {
  description = "New Relic account ID. NEW_RELIC_API_KEY must be provided through the environment."
  type        = number
  default     = null

  validation {
    condition     = !var.enable_newrelic_observability_resources || var.newrelic_account_id != null
    error_message = "newrelic_account_id must be set when enable_newrelic_observability_resources is true."
  }
}

variable "newrelic_region" {
  description = "New Relic account region used by the Terraform provider."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU", "JP"], var.newrelic_region)
    error_message = "newrelic_region must be one of US, EU, or JP."
  }
}

variable "newrelic_app_name" {
  description = "APM application name used in dashboard and alert NRQL."
  type        = string
  default     = null
}

variable "business_environment" {
  description = "Environment attribute emitted by car-repair-app custom business events."
  type        = string
  default     = null
}

variable "kong_namespace" {
  description = "Namespace where Kong runs for troubleshooting widgets."
  type        = string
  default     = "kong"
}

variable "newrelic_dashboard_permissions" {
  description = "Permissions for the New Relic dashboard."
  type        = string
  default     = "public_read_only"

  validation {
    condition     = contains(["private", "public_read_only", "public_read_write"], var.newrelic_dashboard_permissions)
    error_message = "newrelic_dashboard_permissions must be private, public_read_only, or public_read_write."
  }
}

variable "newrelic_alert_incident_preference" {
  description = "New Relic alert policy incident rollup strategy."
  type        = string
  default     = "PER_POLICY"

  validation {
    condition     = contains(["PER_POLICY", "PER_CONDITION", "PER_CONDITION_AND_TARGET"], var.newrelic_alert_incident_preference)
    error_message = "newrelic_alert_incident_preference must be PER_POLICY, PER_CONDITION, or PER_CONDITION_AND_TARGET."
  }
}

variable "newrelic_error_rate_warning_threshold" {
  description = "Warning threshold for API error rate percentage."
  type        = number
  default     = 2
}

variable "newrelic_error_rate_critical_threshold" {
  description = "Critical threshold for API error rate percentage."
  type        = number
  default     = 5
}

variable "newrelic_latency_p95_warning_seconds" {
  description = "Warning threshold for API p95 latency in seconds."
  type        = number
  default     = 1
}

variable "newrelic_latency_p95_critical_seconds" {
  description = "Critical threshold for API p95 latency in seconds."
  type        = number
  default     = 2
}

variable "newrelic_available_replicas_warning_threshold" {
  description = "Warning threshold for latest available replicas of the car-repair-app deployment."
  type        = number
  default     = 2
}

variable "newrelic_available_replicas_critical_threshold" {
  description = "Critical threshold for latest available replicas of the car-repair-app deployment."
  type        = number
  default     = 1
}

variable "newrelic_restart_warning_threshold" {
  description = "Warning threshold for container restart delta over the alert window."
  type        = number
  default     = 1
}

variable "newrelic_restart_critical_threshold" {
  description = "Critical threshold for container restart delta over the alert window."
  type        = number
  default     = 3
}

variable "newrelic_loss_of_signal_expiration_seconds" {
  description = "Loss-of-signal expiration duration for production Kubernetes alert conditions."
  type        = number
  default     = 900
}
