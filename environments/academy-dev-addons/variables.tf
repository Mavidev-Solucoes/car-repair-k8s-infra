variable "aws_region" {
  description = "AWS region used by the Academy Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "academy_base_state_bucket" {
  description = "S3 bucket that stores the Academy base Terraform state."
  type        = string
  default     = "car-repair-k8s-infra-terraform-state"
}

variable "academy_base_state_key" {
  description = "S3 object key for the Academy base Terraform state."
  type        = string
  default     = "academy-dev/base/terraform.tfstate"
}

variable "node_group_name" {
  description = "Managed node group name created by the Academy base root."
  type        = string
  default     = "default"
}

variable "metrics_server_chart_version" {
  description = "Metrics Server chart version."
  type        = string
  default     = "3.12.2"
}

variable "kong_namespace" {
  description = "Namespace where Kong Gateway and Kong Ingress Controller are installed."
  type        = string
  default     = "kong"
}

variable "kong_chart_version" {
  description = "Kong official ingress Helm chart version."
  type        = string
  default     = "0.24.0"
}

variable "kong_gateway_image_tag" {
  description = "Kong Gateway image tag used by the Kong ingress Helm chart."
  type        = string
  default     = "3.9"
}

variable "kong_ingress_controller_image_tag" {
  description = "Kong Ingress Controller image tag used by the Kong ingress Helm chart."
  type        = string
  default     = "3.5"
}

variable "kong_ingress_class" {
  description = "IngressClass name watched by Kong Ingress Controller."
  type        = string
  default     = "kong"
}

variable "kong_proxy_node_port" {
  description = "Fixed NodePort exposed by Kong proxy HTTP service."
  type        = number
  default     = 30080

  validation {
    condition     = var.kong_proxy_node_port >= 30000 && var.kong_proxy_node_port <= 32767
    error_message = "kong_proxy_node_port must be inside the Kubernetes NodePort range 30000-32767."
  }
}

variable "kong_nlb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the public Kong NLB on TCP/80."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "newrelic_chart_version" {
  description = "New Relic nri-bundle Helm chart version."
  type        = string
  default     = "8.0.10"
}

variable "newrelic_namespace" {
  description = "Namespace where New Relic Kubernetes integration is installed."
  type        = string
  default     = "newrelic"
}

variable "newrelic_release_name" {
  description = "New Relic Helm release name."
  type        = string
  default     = "newrelic-bundle"
}

variable "newrelic_license_secret_name" {
  description = "Pre-existing Kubernetes Secret containing the New Relic license key."
  type        = string
  default     = "newrelic-license"
}

variable "newrelic_license_secret_key" {
  description = "Key inside the New Relic Kubernetes Secret."
  type        = string
  default     = "licenseKey"
}

variable "additional_tags" {
  description = "Additional tags applied to AWS resources managed by the Academy addons root."
  type        = map(string)
  default     = {}
}
