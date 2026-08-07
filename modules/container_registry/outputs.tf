output "repository_arn" {
  description = "ARN of the private frontend ECR repository."
  value       = aws_ecr_repository.frontend.arn
}

output "repository_name" {
  description = "Name of the private frontend ECR repository."
  value       = aws_ecr_repository.frontend.name
}

output "repository_url" {
  description = "Registry URL used by CI to tag and push immutable frontend images."
  value       = aws_ecr_repository.frontend.repository_url
}
