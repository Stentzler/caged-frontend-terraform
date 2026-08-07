# This data source finds usable zones only while the network component is enabled.
# A one-AZ MVP uses the first returned zone unless availability_zone is explicitly set.
data "aws_availability_zones" "available" {
  count = var.enable_network
  state = "available"
}

# The control-plane flag creates or removes the complete network as one coherent
# unit. Do not add independently toggled resources that depend on this module.
module "network" {
  count  = var.enable_network
  source = "../../modules/network"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  availability_zone  = coalesce(var.availability_zone, data.aws_availability_zones.available[0].names[0])
  tags               = local.tags
}

# This repository is independent from the network, so its component control can
# be changed without affecting VPC resources. Disabling it destroys the ECR
# repository only when it is empty because force_delete remains false.
module "container_registry" {
  count  = var.enable_container_registry
  source = "../../modules/container_registry"

  repository_name = "${local.name_prefix}-next"
  tags            = local.tags
}

# This component creates the EC2 origin, EIP, IAM identity, and origin secret.
module "frontend_host" {
  count  = var.enable_frontend_host
  source = "../../modules/frontend_host"

  host_name               = "${local.name_prefix}-host"
  frontend_repository_arn = one(module.container_registry[*].repository_arn)
  query_lambda_alias_arn  = var.query_lambda_alias_arn
  subnet_id               = one(module.network[*].public_subnet_id)
  security_group_id       = one(module.network[*].frontend_origin_security_group_id)
  aws_region              = var.aws_region
  instance_type           = var.instance_type
  root_volume_size_gib    = var.root_volume_size_gib
  tags                    = local.tags
}

# WAF is a CloudFront-scoped global resource and therefore receives the
# explicitly aliased us-east-1 provider rather than the regional default.
module "edge_delivery" {
  count  = var.enable_edge_delivery
  source = "../../modules/edge_delivery"

  # CloudFront reads the origin secret from SSM, which the host component
  # creates. This ordering defers that read until the same apply has created it.
  depends_on = [module.frontend_host]

  providers = {
    aws = aws.us_east_1
  }

  name                          = "${local.name_prefix}-edge"
  waf_rate_limit                = var.waf_rate_limit
  waf_evaluation_window_seconds = var.waf_evaluation_window_seconds
  origin_domain_name            = one(module.frontend_host[*].origin_domain_name)
  origin_secret_parameter_name  = one(module.frontend_host[*].origin_verification_parameter_name)
  tags                          = local.tags
}

module "github_deployment" {
  count          = var.enable_github_deployment
  source         = "../../modules/github_deployment"
  name           = "${local.name_prefix}-dev"
  repository_arn = one(module.container_registry[*].repository_arn)
  instance_id    = one(module.frontend_host[*].instance_id)
  tags           = local.tags
}
