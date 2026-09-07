output "cluster_endpoint" {
  description = "Amazon EKS cluster endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Amazon EKS cluster name."
  value       = module.eks.cluster_name
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN used by IRSA."
  value       = module.eks.oidc_provider_arn
}

output "aws_load_balancer_controller_role_arn" {
  description = "IRSA role ARN for the AWS Load Balancer Controller."
  value       = module.irsa_aws_load_balancer_controller.arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role ARN for Cluster Autoscaler."
  value       = module.irsa_cluster_autoscaler.arn
}
