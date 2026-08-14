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

# This independent repository holds immutable static portfolio images. It can
# be created before the GitHub repository and its OIDC subject are available.
variable "enable_portfolio_container_registry" {
  description = "Set to 1 to create the portfolio ECR repository, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1], var.enable_portfolio_container_registry)
    error_message = "enable_portfolio_container_registry must be either 0 or 1."
  }
}

# This switch controls the complete EC2 origin component: IAM identity, secret,
# instance, and Elastic IP. It cannot exist without its network and ECR inputs.
variable "enable_frontend_host" {
  description = "Set to 1 to create the frontend EC2 host component, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    # Keeping the same numeric contract prevents ambiguous true/false inputs.
    condition     = contains([0, 1], var.enable_frontend_host)
    error_message = "enable_frontend_host must be either 0 or 1."
  }

  validation {
    # `condition` is Terraform's validation rule: true accepts this input;
    # false stops the run and displays the error_message below. `||` means OR,
    # so a disabled host is always valid. When the host is enabled, `&&` means
    # both its network and ECR dependencies must be enabled too.
    condition = var.enable_frontend_host == 0 || (
      var.enable_network == 1 && var.enable_container_registry == 1
    )
    error_message = "enable_frontend_host can be 1 only when enable_network and enable_container_registry are both 1."
  }
}

# Edge delivery is the public entry point, so it is valid only after the origin
# host exists. The WAF and CloudFront distribution will be added together here.
variable "enable_edge_delivery" {
  description = "Set to 1 to create the CloudFront and WAF edge component, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1], var.enable_edge_delivery)
    error_message = "enable_edge_delivery must be either 0 or 1."
  }

  validation {
    # A public distribution without the protected EC2 origin is an invalid
    # component combination and must never produce an applyable plan.
    condition     = var.enable_edge_delivery == 0 || var.enable_frontend_host == 1
    error_message = "enable_edge_delivery can be 1 only when enable_frontend_host is also 1."
  }
}

# A custom viewer domain is an opt-in CloudFront extension. DNS ownership must
# be proven through ACM before the certificate can be attached to CloudFront.
variable "enable_custom_domain" {
  description = "Set to 1 to use the custom-domain ACM certificate with CloudFront, or 0 to use the default CloudFront hostname."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1], var.enable_custom_domain)
    error_message = "enable_custom_domain must be either 0 or 1."
  }

  validation {
    condition     = var.enable_custom_domain == 0 || var.enable_edge_delivery == 1
    error_message = "enable_custom_domain can be 1 only when enable_edge_delivery is also 1."
  }
}

variable "enable_github_deployment" {
  description = "Set to 1 to create the GitHub OIDC deployment role, or 0 to remove it."
  type        = number
  default     = 1

  validation {
    condition     = contains([0, 1], var.enable_github_deployment)
    error_message = "enable_github_deployment must be either 0 or 1."
  }
}

# The portfolio GitHub role stays disabled until the repository exists and its
# organization-specific OIDC subject can be copied exactly into tfvars.
variable "enable_portfolio_github_deployment" {
  description = "Set to 1 to create the portfolio GitHub OIDC deployment role, or 0 to remove it."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1], var.enable_portfolio_github_deployment)
    error_message = "enable_portfolio_github_deployment must be either 0 or 1."
  }

  validation {
    condition = var.enable_portfolio_github_deployment == 0 || (
      var.enable_frontend_host == 1 && var.enable_portfolio_container_registry == 1
    )
    error_message = "enable_portfolio_github_deployment can be 1 only when the frontend host and portfolio repository are enabled."
  }
}

# Routing is part of the existing edge component and is safe only after the
# multi-domain certificate is attached to the shared CloudFront distribution.
variable "enable_portfolio_routing" {
  description = "Set to 1 to route www.stentzler.com.br through CloudFront to the portfolio container."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1], var.enable_portfolio_routing)
    error_message = "enable_portfolio_routing must be either 0 or 1."
  }

  validation {
    condition = var.enable_portfolio_routing == 0 || (
      var.enable_edge_delivery == 1 &&
      var.enable_frontend_host == 1 &&
      var.enable_portfolio_container_registry == 1 &&
      var.enable_portfolio_viewer_domains == 1 &&
      contains(var.portfolio_viewer_domain_names, "stentzler.com.br") &&
      contains(var.portfolio_viewer_domain_names, "www.stentzler.com.br")
    )
    error_message = "enable_portfolio_routing can be 1 only when the host, portfolio repository, edge delivery, and stentzler.com.br/www.stentzler.com.br viewer domains are enabled."
  }
}

# Attach the staged certificate only after its DNS validation records report
# ISSUED in ACM. This switch preserves the existing CAGED certificate until then.
variable "enable_portfolio_viewer_domains" {
  description = "Set to 1 to attach the validated portfolio ACM certificate and aliases to CloudFront."
  type        = number
  default     = 0

  validation {
    condition     = contains([0, 1], var.enable_portfolio_viewer_domains)
    error_message = "enable_portfolio_viewer_domains must be either 0 or 1."
  }

  validation {
    condition = var.enable_portfolio_viewer_domains == 0 || (
      var.enable_custom_domain == 1 && length(var.portfolio_viewer_domain_names) > 0
    )
    error_message = "enable_portfolio_viewer_domains can be 1 only with the existing custom domain and one or more portfolio domains."
  }
}
