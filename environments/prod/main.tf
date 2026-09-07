module "eks_infra" {
  source = "../../terraform"

  project_name = "car-repair"
  environment  = "prod"
  aws_region   = "us-east-1"

  vpc_cidr = "10.20.0.0/16"

  public_subnet_cidrs = [
    "10.20.0.0/24",
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]

  private_subnet_cidrs = [
    "10.20.10.0/24",
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]

  single_nat_gateway = false
  public_access_cidrs = [
    "10.0.0.0/8"
  ]

  eks_managed_node_groups = {
    system = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m6i.large"]
      min_size       = 2
      max_size       = 4
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
      labels = {
        role = "system"
      }
    }
    applications = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["m6i.xlarge"]
      min_size       = 2
      max_size       = 8
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
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
    CostCenter = "platform"
    Tier       = "production"
  }
}
