terraform {
  backend "s3" {
    bucket       = "car-repair-k8s-infra-terraform-state"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
