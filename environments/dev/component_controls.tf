# This file contains controls for complete development infrastructure components.
# Each numeric switch uses 1 to create a component or 0 to remove it on the next
# approved apply. Keep dependent resources together inside the same module.
variable "enable_network" {
  description = "Set to 1 to create the development network component, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    # Reject values such as 2 or -1 before Terraform creates a plan.
    condition     = contains([0, 1], var.enable_network)
    error_message = "enable_network must be either 0 or 1."
  }
}

variable "enable_container_registry" {
  description = "Set to 1 to create the frontend ECR repository, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    # The numeric control pattern is shared by every deployable component.
    condition     = contains([0, 1], var.enable_container_registry)
    error_message = "enable_container_registry must be either 0 or 1."
  }
}

# This switch controls the EC2 host's IAM identity. It creates no compute yet;
variable "enable_frontend_host" {
  description = "Set to 1 to create the frontend host identity component, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    # Keeping the same numeric contract prevents ambiguous true/false inputs.
    condition     = contains([0, 1], var.enable_frontend_host)
    error_message = "enable_frontend_host must be either 0 or 1."
  }
}
