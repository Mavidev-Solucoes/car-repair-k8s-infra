variable "project_name" {
  description = "Project identifier used in AWS resource names."
  type        = string
  default     = "car-repair"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "The environment must be either dev or prod."
  }
}

variable "aws_region" {
  description = "AWS region used to deploy the EKS platform."
  type        = string
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "azs" {
  description = "Availability zones used by the VPC. If omitted, the first three available AZs are used."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets used by worker nodes and internal load balancers."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets used by public load balancers and NAT gateways."
  type        = list(string)
}

variable "enable_nat_gateway" {
  description = "Whether to enable NAT gateways for private subnet egress."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Whether to provision a single shared NAT gateway."
  type        = bool
  default     = true
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS API server is reachable from the internet."
  type        = bool
  default     = true
}

variable "cluster_endpoint_private_access" {
  description = "Whether the EKS API server is reachable from within the VPC."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "Administrative CIDR blocks allowed to access the public EKS API endpoint."
  type        = list(string)

  validation {
    condition     = length(var.public_access_cidrs) > 0
    error_message = "At least one administrative CIDR must be provided for public EKS API endpoint access."
  }

  validation {
    condition     = var.environment != "prod" || !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "Production must not use 0.0.0.0/0 for public EKS API endpoint access. Use a corporate/VPN CIDR or a runner inside the VPC."
  }
}

variable "eks_managed_node_groups" {
  description = "Managed node group definitions passed to the EKS module."
  type        = any
}

variable "application_namespaces" {
  description = "Namespaces created in advance for platform services and workloads."
  type        = list(string)
  default     = ["kong", "newrelic", "car-repair-app"]
}

variable "metrics_server_chart_version" {
  description = "Metrics Server chart version."
  type        = string
  default     = "3.12.2"
}

variable "cluster_autoscaler_chart_version" {
  description = "Cluster Autoscaler chart version."
  type        = string
  default     = "9.46.6"
}

variable "aws_load_balancer_controller_chart_version" {
  description = "AWS Load Balancer Controller chart version."
  type        = string
  default     = "1.13.4"
}

variable "enable_newrelic" {
  description = "Whether to install the New Relic Kubernetes monitoring bundle."
  type        = bool
  default     = false
}

variable "enable_newrelic_observability_resources" {
  description = "Whether to create New Relic dashboards and alert conditions. Independent from enable_newrelic agent installation."
  type        = bool
  default     = false
}

variable "newrelic_account_id" {
  description = "New Relic account ID where dashboards and alerts are managed. The User API key must be provided via NEW_RELIC_API_KEY."
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
  description = "APM application name used in dashboard and alert NRQL. Defaults to car-repair-app-<environment>."
  type        = string
  default     = null
}

variable "business_environment" {
  description = "Environment attribute emitted by car-repair-app custom business events. Defaults to Development for dev and Production for prod."
  type        = string
  default     = null
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

variable "newrelic_chart_version" {
  description = "New Relic nri-bundle Helm chart version."
  type        = string
  default     = "8.0.10"
}

variable "enable_kong" {
  description = "Whether to install Kong Gateway and Kong Ingress Controller."
  type        = bool
  default     = false
}

variable "kong_namespace" {
  description = "Namespace where Kong Gateway and Kong Ingress Controller are installed."
  type        = string
  default     = "kong"
}

variable "kong_ingress_class" {
  description = "IngressClass name watched by Kong Ingress Controller."
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

variable "enable_external_secrets" {
  description = "Whether to install External Secrets Operator in the cluster."
  type        = bool
  default     = false
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator chart version."
  type        = string
  default     = "0.14.4"
}

variable "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator is installed."
  type        = string
  default     = "kube-system"
}

variable "external_secrets_service_account_name" {
  description = "Dedicated service account name used by External Secrets Operator."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_secret_arns" {
  description = "Secrets Manager secret ARNs that External Secrets Operator can read. If empty, access is limited to project/environment-prefixed secrets."
  type        = list(string)
  default     = []
}

variable "external_secrets_kms_key_arns" {
  description = "Optional KMS key ARNs External Secrets Operator can use to decrypt Secrets Manager secrets encrypted with customer-managed keys."
  type        = list(string)
  default     = []
}

variable "ecr_repository_name" {
  description = "ECR repository name for the car-repair-app image. Defaults to a project/environment-scoped repository."
  type        = string
  default     = null
}

variable "ecr_image_tag_mutability" {
  description = "ECR image tag mutability policy."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ECR image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_untagged_image_expire_days" {
  description = "Number of days to keep untagged ECR images."
  type        = number
  default     = 14
}

variable "ecr_tagged_image_count" {
  description = "Maximum number of tagged ECR images to retain."
  type        = number
  default     = 30
}

variable "additional_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
