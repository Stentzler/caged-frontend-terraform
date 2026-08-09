locals {
  # A consistent prefix keeps names understandable in the AWS console.
  name_prefix = "${var.project_name}-${var.environment}"

  # This stable hierarchy makes the single runtime env-file easy to locate
  # without exposing its contents in outputs or GitHub workflow logs.
  runtime_environment_parameter_name = "/caged/${var.environment}/frontend/runtime-env"

  # This stable path lets deployment automation resolve the current EC2 ID
  # without storing a replacement-sensitive identifier in GitHub.
  deployment_target_parameter_name = "/caged/${var.environment}/frontend/deployment-target-instance-id"

  # Mandatory tags are merged last, so callers cannot replace their values.
  mandatory_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Repository  = "caged-frontend-terraform"
  }

  tags = merge(var.common_tags, local.mandatory_tags)
}
