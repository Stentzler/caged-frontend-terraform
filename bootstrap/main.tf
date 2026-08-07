resource "aws_s3_bucket" "terraform_state" {
  # This bucket holds the remote Terraform state file and its lockfile.
  bucket = local.state_bucket_name

  # Terraform cannot delete a non-empty state bucket during a destroy operation.
  force_destroy = false

  lifecycle {
    # Require an intentional code change before Terraform can destroy the bucket.
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  # S3 retains prior copies of a state object whenever Terraform writes a new one.
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  # Encrypt every object at rest with S3-managed encryption keys (SSE-S3).
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  # These four settings prevent ACLs or bucket policies from making state public.
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  # Disable ACLs and ensure this AWS account owns every object in the bucket.
  # This does not grant access; IAM and bucket policies still control access.
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "terraform_state" {
  # Build the bucket policy as Terraform data rather than a hand-written JSON string.
  statement {
    # An explicit Deny always wins, even when an IAM policy would otherwise allow access.
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      # This statement evaluates every caller, but only denies HTTP transport.
      type        = "*"
      identifiers = ["*"]
    }

    # Apply the HTTPS requirement to every S3 action on the bucket and objects.
    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      # `false` means the request was not sent over HTTPS.
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  # Attach the TLS-only policy generated above to the state bucket.
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state.json
}
