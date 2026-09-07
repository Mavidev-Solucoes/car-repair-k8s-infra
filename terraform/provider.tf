provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(var.additional_tags, local.common_tags)
  }
}

provider "kubernetes" {
  host                   = try(data.aws_eks_cluster.this.endpoint, null)
  token                  = try(data.aws_eks_cluster_auth.this.token, null)
  cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), null)
}

provider "helm" {
  kubernetes {
    host                   = try(data.aws_eks_cluster.this.endpoint, null)
    token                  = try(data.aws_eks_cluster_auth.this.token, null)
    cluster_ca_certificate = try(base64decode(data.aws_eks_cluster.this.certificate_authority[0].data), null)
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}
