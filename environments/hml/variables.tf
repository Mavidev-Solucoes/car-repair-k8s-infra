variable "project_name" {
  description = "Project identifier used in AWS resource names for hml."
  type        = string
  default     = "car-repair"
}

variable "aws_region" {
  description = "AWS region used to deploy the hml EKS platform."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version for hml."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the hml VPC."
  type        = string
  default     = "10.15.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for hml public subnets."
  type        = list(string)
  default     = ["10.15.0.0/24", "10.15.1.0/24", "10.15.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for hml private subnets."
  type        = list(string)
  default     = ["10.15.10.0/24", "10.15.11.0/24", "10.15.12.0/24"]
}

variable "public_access_cidrs" {
  description = "Administrative CIDR blocks allowed to access the public EKS API endpoint in hml."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "single_nat_gateway" {
  description = "Whether hml should use a single shared NAT gateway."
  type        = bool
  default     = true
}

variable "eks_managed_node_groups" {
  description = "Managed node group definitions for hml."
  type        = any
  default = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      labels = {
        role = "system"
      }
    }
    applications = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      capacity_type  = "SPOT"
      labels = {
        role = "applications"
      }
      taints = {
        workloads = {
          key    = "workload"
          value  = "dotnet"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

variable "enable_external_secrets" {
  description = "Whether to install External Secrets Operator in hml."
  type        = bool
  default     = false
}

variable "enable_kong" {
  description = "Whether to install Kong Gateway and Kong Ingress Controller in hml."
  type        = bool
  default     = false
}

variable "kong_chart_version" {
  description = "Kong official ingress Helm chart version for hml."
  type        = string
  default     = "0.24.0"
}

variable "enable_newrelic" {
  description = "Whether to install New Relic Kubernetes monitoring in hml."
  type        = bool
  default     = false
}

variable "newrelic_chart_version" {
  description = "New Relic nri-bundle Helm chart version for hml."
  type        = string
  default     = "8.0.10"
}

variable "enable_newrelic_observability_resources" {
  description = "Whether to create New Relic dashboards and alerts in hml."
  type        = bool
  default     = false
}

variable "newrelic_account_id" {
  description = "New Relic account ID for hml dashboards and alerts."
  type        = number
  default     = null
}

variable "newrelic_region" {
  description = "New Relic account region for hml."
  type        = string
  default     = "US"
}

variable "newrelic_app_name" {
  description = "New Relic APM app name for hml."
  type        = string
  default     = "car-repair-app-hml"
}

variable "business_environment" {
  description = "Environment attribute emitted by car-repair-app custom business events in hml."
  type        = string
  default     = "Staging"
}
