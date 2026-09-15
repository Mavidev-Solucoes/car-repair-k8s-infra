variable "enable_external_secrets" {
  description = "Whether to install External Secrets Operator in prod."
  type        = bool
  default     = false
}

variable "enable_kong" {
  description = "Whether to install Kong Gateway and Kong Ingress Controller in prod."
  type        = bool
  default     = false
}

variable "kong_chart_version" {
  description = "Kong official ingress Helm chart version for prod."
  type        = string
  default     = "0.24.0"
}

variable "enable_newrelic" {
  description = "Whether to install New Relic Kubernetes monitoring in prod."
  type        = bool
  default     = false
}

variable "newrelic_chart_version" {
  description = "New Relic nri-bundle Helm chart version for prod."
  type        = string
  default     = "8.0.10"
}
