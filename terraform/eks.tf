locals {
  eks_managed_node_groups = {
    for name, config in var.eks_managed_node_groups :
    name => merge(
      config,
      {
        tags = merge(
          try(config.tags, {}),
          {
            "k8s.io/cluster-autoscaler/enabled"              = "true"
            "k8s.io/cluster-autoscaler/${local.name_prefix}" = "owned"
          }
        )
      }
    )
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = local.name_prefix
  kubernetes_version = var.kubernetes_version

  authentication_mode                      = "API_AND_CONFIG_MAP"
  enable_cluster_creator_admin_permissions = true

  endpoint_public_access       = var.cluster_endpoint_public_access
  endpoint_private_access      = var.cluster_endpoint_private_access
  endpoint_public_access_cidrs = var.public_access_cidrs

  create_cloudwatch_log_group            = true
  cloudwatch_log_group_retention_in_days = 30

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
  }

  eks_managed_node_groups = local.eks_managed_node_groups

  tags = local.common_tags
}
