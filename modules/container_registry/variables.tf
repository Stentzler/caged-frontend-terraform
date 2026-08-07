variable "repository_name" {
  description = "Name assigned to the private frontend ECR repository."
  type        = string

  validation {
    # ECR repository names use lowercase path segments separated by slashes.
    condition     = can(regex("^[a-z0-9]+(?:[._/-][a-z0-9]+)*$", var.repository_name))
    error_message = "repository_name must be a valid lowercase ECR repository name."
  }
}

variable "tags" {
  description = "Mandatory and optional tags supplied by the environment root."
  type        = map(string)
}
