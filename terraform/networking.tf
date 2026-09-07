locals {
  project_name = "car-repair-shop"
  resource_prefix = "car-repair-${var.environment}"
  selected_azs = length(var.azs) > 0 ? var.azs : slice(data.aws_availability_zones.available.names, 0, 3)
  common_tags  = {
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
    "kubernetes.io/cluster/${local.resource_prefix}" = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.resource_prefix}" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }

  tags = local.common_tags
}
