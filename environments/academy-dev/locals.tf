locals {
  resource_prefix = "${var.project_name}-${var.environment}"
  cluster_name    = local.resource_prefix

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Owner       = "FIAP-TechChallenge"
      LabProfile  = "AWSAcademyLearnerLab"
    },
    var.additional_tags
  )
}
