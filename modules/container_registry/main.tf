locals {
  # These values keep rollback capacity while automatically clearing build leftovers.
  retained_tagged_image_count = 3
  untagged_expiration_days    = 3
}

# A private ECR repository stores immutable container images for the Next.js
# application. Terraform creates the repository but never builds or pushes images.
resource "aws_ecr_repository" "frontend" {
  name                 = var.repository_name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  encryption_configuration {
    # SSE-S3 provides encryption at rest without the extra cost and key management of a CMK.
    encryption_type = "AES256"
  }

  image_scanning_configuration {
    # ECR scans each pushed image for known vulnerabilities.
    scan_on_push = true
  }

  tags = merge(var.tags, {
    Name = var.repository_name
  })
}

# One lifecycle policy can contain several ordered rules. Rule 1 removes only
# untagged images that are at least three days old; these are typically failed
# builds or unreferenced layers. Rule 2 retains the three newest tagged images
# forever by expiring older tagged images, preserving a small rollback history.
resource "aws_ecr_lifecycle_policy" "frontend" {
  repository = aws_ecr_repository.frontend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after ${local.untagged_expiration_days} days."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = local.untagged_expiration_days
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Retain the ${local.retained_tagged_image_count} newest tagged release images."
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = local.retained_tagged_image_count
        }
        action = {
          type = "expire"
        }
      },
    ]
  })
}

# A plan-time assertion documents the intentional low-cost retention contract.
check "frontend_image_retention" {
  assert {
    condition = (
      local.retained_tagged_image_count == 3 &&
      local.untagged_expiration_days == 3
    )
    error_message = "The frontend registry must retain three tagged images and expire untagged images after three days."
  }
}
