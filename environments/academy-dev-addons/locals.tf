locals {
  cluster_name = data.terraform_remote_state.academy_base.outputs.cluster_name
  vpc_id       = data.terraform_remote_state.academy_base.outputs.vpc_id

  common_tags = merge(
    {
      Project     = "car-repair"
      Environment = "dev"
      ManagedBy   = "Terraform"
      Owner       = "FIAP-TechChallenge"
      LabProfile  = "AWSAcademyLearnerLab"
    },
    var.additional_tags
  )

  kong_node_autoscaling_group_name = data.aws_eks_node_group.default.resources[0].autoscaling_groups[0].name
}
