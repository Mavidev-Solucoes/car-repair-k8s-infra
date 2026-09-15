provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.academy_base.outputs.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.this.token
  cluster_ca_certificate = base64decode(data.terraform_remote_state.academy_base.outputs.cluster_certificate_authority_data)
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.academy_base.outputs.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(data.terraform_remote_state.academy_base.outputs.cluster_certificate_authority_data)
  }
}
