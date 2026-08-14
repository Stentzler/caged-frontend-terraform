output "role_arn" {
  description = "ARN of the GitHub Actions OIDC role used by the deployment workflow."
  value       = aws_iam_role.deployment.arn
}
