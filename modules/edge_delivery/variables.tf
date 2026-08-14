# This name identifies the CloudFront-scoped WAF resources in the global region.
variable "name" {
  description = "Name prefix for edge-delivery resources."
  type        = string
}

variable "waf_rate_limit" {
  description = "Maximum qualifying POST requests per IP in each WAF window."
  type        = number
}

variable "waf_evaluation_window_seconds" {
  description = "Length in seconds of the AWS WAF rate evaluation window."
  type        = number
}

variable "enable_custom_domain" {
  description = "Whether CloudFront should serve the optional viewer domain with its ACM certificate."
  type        = number
}

variable "viewer_domain_name" {
  description = "Optional CloudFront viewer domain covered by the ACM certificate."
  type        = string
  nullable    = true
}

variable "portfolio_viewer_domain_names" {
  description = "Additional portfolio viewer hostnames, excluding the existing CAGED viewer hostname."
  type        = set(string)
  default     = []
}

variable "enable_portfolio_viewer_domains" {
  description = "Whether the validated multi-domain ACM certificate should be attached to CloudFront."
  type        = number
  default     = 0
}

variable "enable_portfolio_routing" {
  description = "Whether CloudFront should route the canonical portfolio hostname to the shared EC2 portfolio origin."
  type        = number
  default     = 0
}

variable "origin_domain_name" {
  description = "Resolvable EC2 hostname used as the CloudFront custom origin."
  type        = string
}

variable "origin_secret_parameter_name" {
  description = "SSM SecureString parameter name containing the Nginx origin-verification secret."
  type        = string
}

variable "tags" {
  description = "Mandatory and optional tags applied to taggable edge resources."
  type        = map(string)
}
