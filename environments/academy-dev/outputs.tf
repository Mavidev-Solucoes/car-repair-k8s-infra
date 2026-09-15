output "cluster_name" {
  description = "Amazon EKS cluster name."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Amazon EKS cluster endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Amazon EKS Kubernetes version."
  value       = aws_eks_cluster.this.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded EKS cluster certificate authority data."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "vpc_id" {
  description = "VPC ID used by the Academy cluster."
  value       = aws_vpc.this.id
}

output "private_subnets" {
  description = "Private subnet IDs used by Academy managed nodes and workloads."
  value       = aws_subnet.private[*].id
}

output "public_subnets" {
  description = "Public subnet IDs used by NAT and public load balancers."
  value       = aws_subnet.public[*].id
}

output "node_security_group_id" {
  description = "EKS primary cluster security group. EKS attaches this security group to managed node ENIs, so it is valid as the source security group for RDS ingress."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "ecr_repository_url" {
  description = "ECR repository URL for car-repair-app."
  value       = aws_ecr_repository.car_repair_app.repository_url
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL published by EKS. Academy does not create an IAM OIDC provider in this root."
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN. Null in Academy because this root intentionally does not create aws_iam_openid_connect_provider."
  value       = null
}
