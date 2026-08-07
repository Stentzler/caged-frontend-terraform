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

# The host identity needs both an existing network destination and the specific
# ECR repository it is allowed to pull from. Fail before planning if either
# dependency is deliberately disabled.
check "frontend_host_dependencies" {
  assert {
    condition     = var.enable_frontend_host == 0 || (var.enable_network == 1 && var.enable_container_registry == 1)
    error_message = "enable_frontend_host requires both enable_network and enable_container_registry to be 1."
  }
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
