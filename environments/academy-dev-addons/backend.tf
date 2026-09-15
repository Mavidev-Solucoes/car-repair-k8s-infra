terraform {
  backend "s3" {
    bucket       = "car-repair-k8s-infra-terraform-state"
    key          = "academy-dev/addons/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
