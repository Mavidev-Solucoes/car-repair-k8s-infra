output "cluster_endpoint" {
  value = module.eks_infra.cluster_endpoint
}

output "cluster_name" {
  value = module.eks_infra.cluster_name
}

output "oidc_provider_arn" {
  value = module.eks_infra.oidc_provider_arn
}
