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

output "node_security_group_id" {
  description = "Security group ID used by the EKS worker nodes."
  value       = module.eks.node_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for car-repair-app."
  value       = aws_ecr_repository.car_repair_app.repository_url
}

output "external_secrets_role_arn" {
  description = "IAM role ARN used by External Secrets Operator when enabled."
  value       = var.enable_external_secrets ? aws_iam_role.external_secrets[0].arn : null
}

output "external_secrets_service_account_name" {
  description = "Service account name used by External Secrets Operator when enabled."
  value       = var.enable_external_secrets ? var.external_secrets_service_account_name : null
}

output "cluster_autoscaler" {
  description = "Cluster Autoscaler settings useful for troubleshooting."
  value = {
    cluster_name         = local.cluster_name
    namespace            = local.cluster_autoscaler_namespace
    service_account_name = local.cluster_autoscaler_service_account_name
    irsa_role_arn        = module.irsa_cluster_autoscaler.arn
    irsa_role_name       = module.irsa_cluster_autoscaler.name
    irsa_policy_arn      = module.irsa_cluster_autoscaler.iam_policy_arn
    auto_discovery_tags  = local.cluster_autoscaler_node_group_tags
    helm_chart_version   = var.cluster_autoscaler_chart_version
    aws_region           = var.aws_region
    managed_node_groups  = sort(keys(var.eks_managed_node_groups))
  }
}
