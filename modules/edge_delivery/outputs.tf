# CloudFront will attach this ACL directly when the distribution is added.
output "web_acl_arn" {
  description = "ARN of the CloudFront-scoped WAF web ACL."
  value       = aws_wafv2_web_acl.frontend.arn
}

output "distribution_domain_name" {
  description = "CloudFront viewer hostname for the frontend."
  value       = aws_cloudfront_distribution.frontend.domain_name
}

# These records are safe to share with the DNS administrator. They prove domain
# control to ACM; they do not expose the certificate private key or origin secret.
output "custom_domain_validation_records" {
  description = "DNS CNAME records required to validate the requested custom-domain ACM certificate."
  value = var.enable_custom_domain == 1 ? [
    for option in aws_acm_certificate.viewer[0].domain_validation_options : {
      name  = option.resource_record_name
      type  = option.resource_record_type
      value = option.resource_record_value
    }
  ] : []
}
