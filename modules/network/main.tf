locals {
  # This module uses a stable name pattern across all of its network resources.
  name_prefix = "${var.project_name}-${var.environment}"

  # Stable keys make each egress rule independently identifiable in Terraform state.
  egress_rules = {
    http = {
      description = "Allow Ubuntu package installation and updates over HTTP."
      from_port   = 80
      ip_protocol = "tcp"
      to_port     = 80
      cidr_ipv4   = "0.0.0.0/0"
    }
    https = {
      description = "Allow AWS APIs, ECR, SSM, Lambda, and HTTPS package repositories."
      from_port   = 443
      ip_protocol = "tcp"
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
    dns_tcp = {
      description = "Allow DNS zone transfers and large DNS responses when TCP is required."
      from_port   = 53
      ip_protocol = "tcp"
      to_port     = 53
      cidr_ipv4   = "0.0.0.0/0"
    }
    dns_udp = {
      description = "Allow normal DNS resolution for operating-system and AWS service names."
      from_port   = 53
      ip_protocol = "udp"
      to_port     = 53
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

# A VPC is a private, logically isolated network. DNS support and hostnames are
# required so the EC2 origin can resolve AWS service names and receive a public DNS name.
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# An Internet Gateway connects this VPC's public route table to the internet.
# It has no hourly charge; the later EC2 public IPv4 and data transfer do cost money.
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-internet-gateway"
  })
}

# This is the only subnet in the MVP and therefore deliberately uses one AZ.
# It is public because its route table reaches the Internet Gateway, not because
# instances automatically receive a public IPv4 address.
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-subnet"
    Tier = "public"
  })
}

# A route table decides where packets leave the subnet. This one contains the
# default IPv4 route to the Internet Gateway, making the subnet public.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-public-route-table"
  })
}

resource "aws_route" "public_internet_ipv4" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Associate the one subnet with the public route table instead of the VPC's
# default route table, making the network topology explicit and reproducible.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# AWS maintains this prefix list as CloudFront origin-facing IP addresses change.
# Looking it up avoids copying CIDRs into source code and accidentally becoming stale.
data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# This stateful firewall will be attached to the future EC2 origin. It starts
# with no inline rules; explicit rule resources below make each permission clear.
resource "aws_security_group" "frontend_origin" {
  name        = "${local.name_prefix}-frontend-origin"
  description = "CloudFront-only ingress and restricted runtime egress for the frontend origin."
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-frontend-origin"
  })
}

# Only CloudFront's AWS-managed origin-facing addresses can reach Nginx on port 80.
# There is intentionally no SSH, HTTPS, or Next.js port 3000 ingress rule.
resource "aws_vpc_security_group_ingress_rule" "cloudfront_http" {
  security_group_id = aws_security_group.frontend_origin.id
  description       = "Allow HTTP origin traffic only from CloudFront origin-facing infrastructure."
  from_port         = 80
  ip_protocol       = "tcp"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id
  to_port           = 80
}

# Create one explicitly named outbound rule per allowed runtime requirement.
# `for_each` keeps rule identity stable if a new allowed destination is added later.
resource "aws_vpc_security_group_egress_rule" "runtime" {
  for_each = local.egress_rules

  security_group_id = aws_security_group.frontend_origin.id
  description       = each.value.description
  from_port         = each.value.from_port
  ip_protocol       = each.value.ip_protocol
  to_port           = each.value.to_port
  cidr_ipv4         = each.value.cidr_ipv4
}

# These assertions make security requirements visible in every plan. The sole
# ingress rule must stay CloudFront-only HTTP; adding SSH or port 3000 requires
# changing this module and would be caught in review.
check "cloudfront_only_origin_ingress" {
  assert {
    condition = (
      aws_vpc_security_group_ingress_rule.cloudfront_http.from_port == 80 &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.to_port == 80 &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.ip_protocol == "tcp" &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.prefix_list_id == data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.cidr_ipv4 == null &&
      aws_vpc_security_group_ingress_rule.cloudfront_http.cidr_ipv6 == null
    )
    error_message = "The frontend origin may accept only CloudFront prefix-list traffic on TCP port 80."
  }
}
