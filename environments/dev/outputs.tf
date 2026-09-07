output "cluster_name" {
  value = module.eks_infra.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_infra.cluster_endpoint
}

output "cluster_version" {
  value = module.eks_infra.cluster_version
}

output "oidc_provider_arn" {
  value = module.eks_infra.oidc_provider_arn
}

output "oidc_provider_url" {
  value = module.eks_infra.oidc_provider_url
}

output "vpc_id" {
  value = module.eks_infra.vpc_id
}

output "public_subnets" {
  value = module.eks_infra.public_subnets
}

output "private_subnets" {
  value = module.eks_infra.private_subnets
}

output "cluster_autoscaler" {
  value = module.eks_infra.cluster_autoscaler
}
