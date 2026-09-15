module "eks_infra" {
  source = "../../terraform"

  project_name = var.project_name
  environment  = "hml"
  aws_region   = var.aws_region

  kubernetes_version = var.kubernetes_version

  vpc_cidr = var.vpc_cidr

  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  single_nat_gateway = var.single_nat_gateway

  enable_external_secrets = var.enable_external_secrets
  enable_kong             = var.enable_kong
  kong_chart_version      = var.kong_chart_version
  enable_newrelic         = var.enable_newrelic
  newrelic_chart_version  = var.newrelic_chart_version

  public_access_cidrs = var.public_access_cidrs

  eks_managed_node_groups = var.eks_managed_node_groups

  additional_tags = {
    CostCenter = "devops"
    Tier       = "homologation"
  }
}
