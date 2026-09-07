output "cluster_name" {
  description = "Amazon EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Amazon EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Amazon EKS Kubernetes version."
  value       = module.eks.cluster_version
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for the cluster."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL for the cluster."
  value       = module.eks.cluster_oidc_issuer_url
}

output "vpc_id" {
  description = "VPC ID used by the cluster."
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "Public subnet IDs associated with the platform VPC."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "Private subnet IDs associated with the platform VPC."
  value       = module.vpc.private_subnets
}
