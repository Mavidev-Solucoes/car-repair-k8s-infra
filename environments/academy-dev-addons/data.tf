data "terraform_remote_state" "academy_base" {
  backend = "s3"

  config = {
    bucket = var.academy_base_state_bucket
    key    = var.academy_base_state_key
    region = var.aws_region
  }
}

data "aws_eks_cluster_auth" "this" {
  name = data.terraform_remote_state.academy_base.outputs.cluster_name
}

data "aws_eks_node_group" "default" {
  cluster_name    = data.terraform_remote_state.academy_base.outputs.cluster_name
  node_group_name = var.node_group_name
}

data "external" "newrelic_license_secret" {
  program = [
    "bash",
    "${path.module}/check-kubernetes-secret.sh",
    var.newrelic_namespace,
    var.newrelic_license_secret_name,
  ]
}
