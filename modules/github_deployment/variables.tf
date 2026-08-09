variable "name" { type = string }
variable "repository_arn" { type = string }
variable "instance_id" { type = string }
variable "deployment_target_parameter_arn" {
  description = "ARN of the non-secret SSM parameter containing the current deployment target instance ID."
  type        = string
}
variable "tags" { type = map(string) }
