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

output "node_security_group_id" {
  value = module.eks_infra.node_security_group_id
}

output "ecr_repository_url" {
  value = module.eks_infra.ecr_repository_url
}

output "external_secrets_role_arn" {
  value = module.eks_infra.external_secrets_role_arn
}

output "external_secrets_service_account_name" {
  value = module.eks_infra.external_secrets_service_account_name
}

output "kong_namespace" {
  value = module.eks_infra.kong_namespace
}

output "kong_ingress_class" {
  value = module.eks_infra.kong_ingress_class
}

output "newrelic_namespace" {
  value = module.eks_infra.newrelic_namespace
}

output "newrelic_enabled" {
  value = module.eks_infra.newrelic_enabled
}

output "newrelic_dashboard_guid" {
  value = module.eks_infra.newrelic_dashboard_guid
}

output "newrelic_dashboard_permalink" {
  value = module.eks_infra.newrelic_dashboard_permalink
}

output "newrelic_alert_policy_id" {
  value = module.eks_infra.newrelic_alert_policy_id
}

output "cluster_autoscaler" {
  value = module.eks_infra.cluster_autoscaler
}
