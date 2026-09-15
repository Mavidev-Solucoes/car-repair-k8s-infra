variable "aws_region" {
  description = "AWS region where the Terraform state bucket is created."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket name used by the Terraform remote backend."
  type        = string
  default     = "car-repair-k8s-infra-terraform-state"
}

variable "project_name" {
  description = "Project identifier used in AWS resource tags."
  type        = string
  default     = "car-repair"
}
