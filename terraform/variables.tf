variable "project_name" {
  description = "Project identifier used in AWS resource names."
  type        = string
  default     = "car-repair"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
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

variable "additional_tags" {
  description = "Additional tags applied to all resources."
  type        = map(string)
  default     = {}
}
