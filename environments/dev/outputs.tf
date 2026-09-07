output "rds_endpoint" {
  value = module.eks_infra.rds_endpoint
}

output "rds_port" {
  value = module.eks_infra.rds_port
}

output "rds_arn" {
  value = module.eks_infra.rds_arn
}

output "secret_arn" {
  value = module.eks_infra.secret_arn
}

output "security_group_id" {
  value = module.eks_infra.security_group_id
}
