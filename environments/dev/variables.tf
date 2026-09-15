variable "enable_external_secrets" {
  description = "Whether to install External Secrets Operator in dev."
  type        = bool
  default     = false
}

variable "enable_kong" {
  description = "Whether to install Kong Gateway and Kong Ingress Controller in dev."
  type        = bool
  default     = false
}

variable "kong_chart_version" {
  description = "Kong official ingress Helm chart version for dev."
  type        = string
  default     = "0.24.0"
}

variable "enable_newrelic" {
  description = "Whether to install New Relic Kubernetes monitoring in dev."
  type        = bool
  default     = false
}

variable "newrelic_chart_version" {
  description = "New Relic nri-bundle Helm chart version for dev."
  type        = string
  default     = "8.0.10"
}

variable "enable_newrelic_observability_resources" {
  description = "Whether to create New Relic dashboards and alerts in dev."
  type        = bool
  default     = false
}

variable "newrelic_account_id" {
  description = "New Relic account ID for dev dashboards and alerts."
  type        = number
  default     = null
}

variable "newrelic_region" {
  description = "New Relic account region for dev."
  type        = string
  default     = "US"
}

variable "newrelic_app_name" {
  description = "New Relic APM app name for dev."
  type        = string
  default     = "car-repair-app-dev"
}
