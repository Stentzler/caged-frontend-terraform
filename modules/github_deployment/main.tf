data "aws_partition" "current" {}
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# The account already owns this provider; read it rather than creating a duplicate.
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    # GitHub's OIDC token must be intended for AWS STS.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # This GitHub organization uses a customized OIDC subject that includes
    # immutable owner and repository IDs. The caller supplies the exact
    # protected-environment subject for its own repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.github_oidc_subject]
    }
  }
}

data "aws_iam_policy_document" "deployment" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:DescribeImages", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
    resources = [var.repository_arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}::document/AWS-RunShellScript", "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/${var.instance_id}"]
  }
  # The workflow reads only this non-secret parameter to discover the current
  # host after Terraform replaces its instance ID.
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = [var.deployment_target_parameter_arn]
  }
  # SSM does not expose command-invocation ARNs for GetCommandInvocation. Limit
  # its required wildcard permission to this deployment Region; SendCommand
  # remains separately restricted to the approved document and EC2 instance.
  statement {
    effect    = "Allow"
    actions   = ["ssm:GetCommandInvocation"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [data.aws_region.current.region]
    }
  }
}

resource "aws_iam_role" "deployment" {
  name               = "${var.name}-github-deployment"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "deployment" {
  name   = "${var.name}-deployment"
  role   = aws_iam_role.deployment.id
  policy = data.aws_iam_policy_document.deployment.json
}
