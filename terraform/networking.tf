locals {
  project_name                            = var.project_name
  resource_prefix                         = "${var.project_name}-${var.environment}"
  cluster_name                            = local.resource_prefix
  selected_azs                            = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 3)
  cluster_autoscaler_namespace            = "kube-system"
  cluster_autoscaler_service_account_name = "cluster-autoscaler"
  cluster_autoscaler_node_group_tags = {
    "k8s.io/cluster-autoscaler/enabled"               = "true"
    "k8s.io/cluster-autoscaler/${local.cluster_name}" = "owned"
  }
  common_tags = {
    Project     = local.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "FIAP-TechChallenge"
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.21"

  name = local.resource_prefix
  cidr = var.vpc_cidr

  azs             = local.selected_azs
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.enable_nat_gateway && !var.single_nat_gateway

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  tags = local.common_tags
}
