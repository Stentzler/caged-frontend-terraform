# This ACL is CloudFront-scoped, so the environment root passes its us-east-1
# provider alias explicitly even when the application Region changes later.
resource "aws_wafv2_web_acl" "frontend" {
  name  = "${var.name}-web-acl"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # A small response body lets browsers receive the standard rate-limit status
  # without exposing implementation details or a diagnostic endpoint.
  custom_response_body {
    key          = "rate_limited"
    content      = "Too many requests. Please try again shortly."
    content_type = "TEXT_PLAIN"
  }

  rule {
    name     = "rate_limit_post_requests"
    priority = 1

    action {
      block {
        custom_response {
          response_code            = 429
          custom_response_body_key = "rate_limited"
        }
      }
    }

    statement {
      rate_based_statement {
        aggregate_key_type    = "IP"
        limit                 = var.waf_rate_limit
        evaluation_window_sec = var.waf_evaluation_window_seconds

        # The MVP has one public POST workflow. Static GET traffic is excluded.
        scope_down_statement {
          byte_match_statement {
            positional_constraint = "EXACTLY"
            search_string         = "POST"

            field_to_match {
              method {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name}-post-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# This lightweight dependency connects the secret read to the host module input
# without deferring unrelated data sources, such as CloudFront's cache policy.
resource "terraform_data" "origin_secret_ready" {
  input = var.origin_secret_parameter_name
}

# Read the same secret used by Nginx without exposing it through an output.
data "aws_ssm_parameter" "origin_verification" {
  name            = var.origin_secret_parameter_name
  with_decryption = true
  depends_on      = [terraform_data.origin_secret_ready]
}

# This policy disables caching for SSR, navigation, and Server Actions while
# the accompanying origin request policy still forwards their needed inputs.
resource "aws_cloudfront_cache_policy" "dynamic" {
  name        = "${var.name}-dynamic-no-cache"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }
  }
}

# AWS maintains this policy for immutable versioned build assets. Using its
# managed ID avoids re-creating standard long-lived cache settings by hand.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# Next.js image optimization needs only its image URL, width, and quality in the
# cache key. A one-day default and seven-day maximum keep the cache bounded.
resource "aws_cloudfront_cache_policy" "next_image" {
  name        = "${var.name}-next-image"
  default_ttl = 86400
  max_ttl     = 604800
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config { cookie_behavior = "none" }
    headers_config { header_behavior = "none" }
    query_strings_config {
      query_string_behavior = "whitelist"
      query_strings { items = ["q", "url", "w"] }
    }
  }
}

# Forward viewer inputs and the AWS-generated client address header to Nginx.
resource "aws_cloudfront_origin_request_policy" "nextjs" {
  name = "${var.name}-nextjs-origin-request"

  cookies_config { cookie_behavior = "all" }
  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers { items = ["CloudFront-Viewer-Address"] }
  }
  query_strings_config { query_string_behavior = "all" }
}

# CloudFront requires its viewer certificate in us-east-1. DNS validation is
# intentionally completed outside Terraform because Registro.br hosts this zone.
resource "aws_acm_certificate" "viewer" {
  count = var.enable_custom_domain

  domain_name       = var.viewer_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}

# CloudFront is the public HTTPS entry point; its HTTP origin connection is the
# accepted MVP trade-off, protected by the SG and the private custom header.
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name} Next.js frontend"
  aliases             = var.enable_custom_domain == 1 ? [var.viewer_domain_name] : []
  price_class         = "PriceClass_200"
  http_version        = "http2and3"
  web_acl_id          = aws_wafv2_web_acl.frontend.arn
  wait_for_deployment = false

  origin {
    domain_name = var.origin_domain_name
    origin_id   = "${var.name}-nginx-origin"

    custom_header {
      name  = "X-Caged-Origin-Verify"
      value = data.aws_ssm_parameter.origin_verification.value
    }

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
      # Required by the provider even though this MVP origin is HTTP-only.
      origin_ssl_protocols = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    target_origin_id         = "${var.name}-nginx-origin"
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
    cache_policy_id          = aws_cloudfront_cache_policy.dynamic.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.nextjs.id
  }

  # Next.js static build assets have hashed names, so immutable caching is safe.
  ordered_cache_behavior {
    path_pattern           = "/_next/static/*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.name}-nginx-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # Image optimization is cacheable, but only with its bounded query-aware key.
  ordered_cache_behavior {
    path_pattern           = "/_next/image*"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.name}-nginx-origin"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.next_image.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # While no custom domain is enabled, CloudFront serves its default hostname.
    # Once enabled, SNI selects the free ACM certificate for the viewer hostname.
    acm_certificate_arn            = var.enable_custom_domain == 1 ? aws_acm_certificate.viewer[0].arn : null
    cloudfront_default_certificate = var.enable_custom_domain == 0
    minimum_protocol_version       = var.enable_custom_domain == 1 ? "TLSv1.2_2021" : null
    ssl_support_method             = var.enable_custom_domain == 1 ? "sni-only" : null
  }
  tags = var.tags
}
