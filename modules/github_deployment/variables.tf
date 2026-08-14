variable "name" {
  description = "Name prefix for the GitHub deployment IAM role and policy."
  type        = string
}

variable "repository_arn" {
  description = "ARN of the ECR repository this GitHub role may publish to."
  type        = string
}

variable "instance_id" {
  description = "ID of the EC2 instance that may receive Systems Manager deployment commands."
  type        = string
}

variable "github_oidc_subject" {
  description = "Exact GitHub Actions OIDC subject allowed to assume this role."
  type        = string
}
variable "deployment_target_parameter_arn" {
  description = "ARN of the non-secret SSM parameter containing the current deployment target instance ID."
  type        = string
}
variable "tags" {
  description = "Mandatory and optional tags applied to the deployment role."
  type        = map(string)
}
