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
