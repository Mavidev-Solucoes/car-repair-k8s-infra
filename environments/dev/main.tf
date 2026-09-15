module "eks_infra" {
  source = "../../terraform"

  project_name = "car-repair"
  environment  = "dev"
  aws_region   = "us-east-1"

  vpc_cidr = "10.10.0.0/16"

  public_subnet_cidrs = [
    "10.10.0.0/24",
    "10.10.1.0/24",
    "10.10.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.10.10.0/24",
    "10.10.11.0/24",
    "10.10.12.0/24"
  ]

  single_nat_gateway = true

  enable_external_secrets                 = var.enable_external_secrets
  enable_kong                             = var.enable_kong
  kong_chart_version                      = var.kong_chart_version
  enable_newrelic                         = var.enable_newrelic
  newrelic_chart_version                  = var.newrelic_chart_version
  enable_newrelic_observability_resources = var.enable_newrelic_observability_resources
  newrelic_account_id                     = var.newrelic_account_id
  newrelic_region                         = var.newrelic_region
  newrelic_app_name                       = var.newrelic_app_name

  public_access_cidrs = [
    "0.0.0.0/0"
  ]

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 3
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      labels = {
        role = "system"
      }
    }
    applications = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.large"]
      min_size       = 1
      max_size       = 4
      desired_size   = 2
      capacity_type  = "SPOT"
      labels = {
        role = "applications"
      }
      taints = {
        workloads = {
          key    = "workload"
          value  = "dotnet"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }

  additional_tags = {
    CostCenter = "devops"
    Tier       = "development"
  }
}
