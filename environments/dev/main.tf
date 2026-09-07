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
