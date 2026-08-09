# EC2 assumes this role through an instance profile; no static access keys are
# created or placed on the future frontend host.
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Canonical maintains this public parameter, avoiding an AMI ID that becomes
# stale or works only in one Region.
data "aws_ssm_parameter" "ubuntu_2404_ami" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# This secret authenticates CloudFront to Nginx. It is never an output.
resource "random_password" "origin_verification" {
  length  = 48
  special = false
}

# The predictable name supports operations while SecureString protects the
# generated value at rest.
resource "aws_ssm_parameter" "origin_verification" {
  name  = "/${var.host_name}/origin-verification"
  type  = "SecureString"
  value = random_password.origin_verification.result
  tags  = var.tags
}

# This single non-secret String parameter acts as the production-style .env
# file for the Next.js container. Keeping it outside the image lets a reviewed
# Terraform change update runtime configuration without committing it to Git.
resource "aws_ssm_parameter" "runtime_environment" {
  name = var.runtime_environment_parameter_name
  type = "String"
  value = templatefile("${path.module}/../../templates/runtime-env.tftpl", {
    aws_region               = var.aws_region
    query_lambda_alias_arn   = var.query_lambda_alias_arn
    site_official_source_url = var.site_official_source_url
    site_cbo_source_url      = var.site_cbo_source_url
    site_github_url          = var.site_github_url
    site_contact_email       = var.site_contact_email
  })
  tags = var.tags
}

# This policy grants the small set of actions required by SSM Session Manager,
# ECR image pulls, runtime configuration reads, and direct Lambda invocation.
data "aws_iam_policy_document" "instance" {
  statement {
    sid    = "SystemsManagerSession"
    effect = "Allow"
    actions = [
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    # These AWS APIs do not support a narrower managed-instance resource ARN.
    resources = ["*"]
  }

  statement {
    sid       = "EcrAuthentication"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PullFrontendImage"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [var.frontend_repository_arn]
  }

  statement {
    sid       = "InvokeQueryLambdaAlias"
    effect    = "Allow"
    actions   = ["lambda:InvokeFunction"]
    resources = [var.query_lambda_alias_arn]
  }

  statement {
    sid     = "ReadHostConfiguration"
    effect  = "Allow"
    actions = ["ssm:GetParameter"]
    # The host may read only its Nginx origin secret and its own runtime .env
    # parameter. It cannot enumerate or read unrelated account parameters.
    resources = [
      aws_ssm_parameter.origin_verification.arn,
      aws_ssm_parameter.runtime_environment.arn,
    ]
  }
}

# The role contains the permissions; the profile is the EC2-specific wrapper
# used later when Terraform launches the instance.
resource "aws_iam_role" "frontend_host" {
  name               = "${var.host_name}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

# An inline policy keeps this one host's access reviewable and avoids attaching
# a broad AWS managed policy with unrelated permissions.
resource "aws_iam_role_policy" "frontend_host" {
  name   = "${var.host_name}-permissions"
  role   = aws_iam_role.frontend_host.id
  policy = data.aws_iam_policy_document.instance.json
}

# EC2 receives temporary credentials through this profile after the instance is
# created in the following implementation step.
resource "aws_iam_instance_profile" "frontend_host" {
  name = "${var.host_name}-profile"
  role = aws_iam_role.frontend_host.name
  tags = var.tags
}

# No SSH key is configured. IMDSv2 provides short-lived IAM credentials to the
# host for ECR, SSM, and Lambda access.
resource "aws_instance" "frontend_host" {
  ami                         = data.aws_ssm_parameter.ubuntu_2404_ami.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = aws_iam_instance_profile.frontend_host.name
  user_data_replace_on_change = true
  user_data = templatefile("${path.module}/../../templates/user-data.sh.tftpl", {
    aws_region                   = var.aws_region
    nginx_configuration          = templatefile("${path.module}/../../templates/nginx.conf.tftpl", {})
    origin_secret_parameter_name = aws_ssm_parameter.origin_verification.name
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = var.root_volume_size_gib
    volume_type = "gp3"
    tags        = merge(var.tags, { Name = "${var.host_name}-root" })
  }

  tags = merge(var.tags, { Name = var.host_name })

  # The bootstrap reads SSM immediately, so attach the access policy first.
  depends_on = [aws_iam_role_policy.frontend_host]
}

# This non-secret value follows the EC2 lifecycle. Deployment automation reads
# it through its own narrowly scoped role instead of keeping an instance ID in
# a GitHub environment variable.
resource "aws_ssm_parameter" "deployment_target" {
  name  = var.deployment_target_parameter_name
  type  = "String"
  value = aws_instance.frontend_host.id
  tags  = var.tags
}

# A separate Elastic IP preserves the origin address when EC2 is replaced.
resource "aws_eip" "frontend_host" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.host_name}-origin" })
}

# Do not use EC2's temporary public IP: CloudFront will use this stable address.
resource "aws_eip_association" "frontend_host" {
  allocation_id = aws_eip.frontend_host.id
  instance_id   = aws_instance.frontend_host.id
}
