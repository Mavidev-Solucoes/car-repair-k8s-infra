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
