variable "project_name" {
  description = "Project identifier used in AWS resource names."
  type        = string
  default     = "car-repair"
}

variable "environment" {
  description = "Academy environment name. Kept as dev so the cluster remains car-repair-dev."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region used by the Academy Learner Lab."
  type        = string
  default     = "us-east-1"
}

variable "kubernetes_version" {
  description = "Amazon EKS Kubernetes version for Academy."
  type        = string
  default     = "1.35"
}

variable "vpc_cidr" {
  description = "CIDR block for the Academy VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "azs" {
  description = "Availability zones used by Academy. Keep these in AZs where t3.medium is available."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets used by NAT and the Academy Kong NLB."
  type        = list(string)
  default     = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets used by EKS workloads and managed nodes."
  type        = list(string)
  default     = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "public_access_cidrs" {
  description = "Administrative CIDR blocks allowed to access the public EKS API endpoint."
  type        = list(string)

  validation {
    condition     = length(var.public_access_cidrs) > 0 && !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "Academy must use a concrete administrative CIDR such as <YOUR_PUBLIC_IP>/32, not 0.0.0.0/0."
  }
}

variable "academy_eks_cluster_role_arn" {
  description = "ARN of the Academy-provided LabEksClusterRole. Terraform does not create or modify this role."
  type        = string
}

variable "academy_eks_node_role_arn" {
  description = "ARN of the Academy-provided LabEksNodeRole. Terraform does not create or modify this role."
  type        = string
}

variable "node_group_name" {
  description = "Managed node group name used by the Academy base and addons roots."
  type        = string
  default     = "default"
}

variable "node_instance_types" {
  description = "EC2 instance types used by the Academy managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_min_size" {
  description = "Minimum size of the Academy managed node group."
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Desired size of the Academy managed node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum size of the Academy managed node group."
  type        = number
  default     = 3
}

variable "node_disk_size" {
  description = "Disk size in GiB for Academy managed nodes."
  type        = number
  default     = 20
}

variable "ecr_repository_name" {
  description = "ECR repository name for car-repair-app in Academy."
  type        = string
  default     = "car-repair-app"
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
  description = "Additional tags applied to all Academy resources."
  type        = map(string)
  default     = {}
}
