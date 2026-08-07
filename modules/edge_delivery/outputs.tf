# CloudFront will attach this ACL directly when the distribution is added.
output "web_acl_arn" {
  description = "ARN of the CloudFront-scoped WAF web ACL."
  value       = aws_wafv2_web_acl.frontend.arn
}

output "distribution_domain_name" {
  description = "CloudFront viewer hostname for the frontend."
  value       = aws_cloudfront_distribution.frontend.domain_name
}
