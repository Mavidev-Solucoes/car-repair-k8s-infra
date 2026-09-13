module "irsa_cluster_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "${local.resource_prefix}-cluster-autoscaler"

  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [local.cluster_name]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.cluster_autoscaler_namespace}:${local.cluster_autoscaler_service_account_name}"]
    }
  }

  tags = local.common_tags
}

module "irsa_aws_load_balancer_controller" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "~> 6.0"

  name = "${local.resource_prefix}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = local.common_tags
}

locals {
  external_secrets_oidc_provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  external_secrets_default_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:car-repair/${var.environment}/*"
  ]
  external_secrets_secret_arns = length(var.external_secrets_secret_arns) > 0 ? var.external_secrets_secret_arns : local.external_secrets_default_secret_arns
}

data "aws_iam_policy_document" "external_secrets_assume_role" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.external_secrets_oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.external_secrets_oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.external_secrets_namespace}:${var.external_secrets_service_account_name}"]
    }
  }
}

resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name               = "${local.resource_prefix}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.external_secrets_assume_role[0].json

  tags = local.common_tags
}

data "aws_iam_policy_document" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  statement {
    sid    = "ReadProjectSecrets"
    effect = "Allow"

    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue"
    ]

    resources = local.external_secrets_secret_arns
  }

  dynamic "statement" {
    for_each = length(var.external_secrets_kms_key_arns) > 0 ? [1] : []

    content {
      sid    = "DecryptSecrets"
      effect = "Allow"

      actions = [
        "kms:Decrypt"
      ]

      resources = var.external_secrets_kms_key_arns

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  name        = "${local.resource_prefix}-external-secrets"
  description = "Least-privilege Secrets Manager read policy for External Secrets Operator."
  policy      = data.aws_iam_policy_document.external_secrets[0].json

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_secrets" {
  count = var.enable_external_secrets ? 1 : 0

  role       = aws_iam_role.external_secrets[0].name
  policy_arn = aws_iam_policy.external_secrets[0].arn
}
