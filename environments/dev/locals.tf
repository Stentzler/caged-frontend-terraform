locals {
  # A consistent prefix keeps names understandable in the AWS console.
  name_prefix = "${var.project_name}-${var.environment}"

  # Mandatory tags are merged last, so callers cannot replace their values.
  mandatory_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Repository  = "caged-frontend-terraform"
  }

  tags = merge(var.common_tags, local.mandatory_tags)
}
