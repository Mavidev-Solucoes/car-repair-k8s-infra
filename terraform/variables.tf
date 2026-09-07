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
  default     = "1.31"
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
  description = "CIDR blocks allowed to access the public EKS API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
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

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "carrepair"
}

variable "db_username" {
  description = "PostgreSQL application username."
  type        = string
  default     = "app_user"

  validation {
    condition     = var.db_username != "postgres"
    error_message = "Use a non-administrative PostgreSQL username."
  }
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16.4"
}

variable "db_parameter_group_family" {
  description = "PostgreSQL parameter group family."
  type        = string
  default     = "postgres16"
}

variable "instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t4g.micro"

  validation {
    condition     = can(regex("^db\\.[a-z0-9]+\\.[a-z0-9]+$", var.instance_class))
    error_message = "The instance_class must follow the RDS format, for example db.t4g.micro."
  }
}

variable "allocated_storage" {
  description = "Initial allocated RDS storage in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "The allocated_storage must be at least 20 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum allocated RDS storage in GB for autoscaling."
  type        = number
  default     = 100
}

variable "allowed_security_groups" {
  description = "Security groups allowed to connect to PostgreSQL on port 5432."
  type        = list(string)
  default     = []
}

variable "additional_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
