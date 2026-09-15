# Primeiro deploy DEV - exemplo sem segredos.
# Copie para terraform.tfvars apenas se quiser sobrescrever os defaults.
# Nao coloque credenciais AWS, New Relic API keys, license keys ou secrets da aplicacao aqui.

project_name       = "car-repair"
aws_region         = "us-east-1"
kubernetes_version = "1.35"

# Nome derivado do cluster: <project_name>-dev, portanto "car-repair-dev".

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

# Para o primeiro deploy real, troque 0.0.0.0/0 por seu IP/VPN quando possivel.
public_access_cidrs = [
  "179.119.77.252/32"
]

single_nat_gateway = true

enable_external_secrets = true
enable_kong             = true
enable_newrelic         = false

# Manter false no primeiro apply. Dashboards/alerts exigem conta New Relic,
# NEW_RELIC_API_KEY e telemetria ja chegando.
enable_newrelic_observability_resources = false

kong_chart_version     = "0.24.0"
newrelic_chart_version = "8.0.10"

newrelic_app_name     = "car-repair-app-dev"
business_environment  = "Development"
newrelic_region       = "US"
newrelic_account_id   = null

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
