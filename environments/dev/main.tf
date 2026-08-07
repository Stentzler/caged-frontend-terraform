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
