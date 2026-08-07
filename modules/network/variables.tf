variable "project_name" {
  description = "Project identifier used in network resource names."
  type        = string
}

variable "environment" {
  description = "Environment identifier used in network resource names."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the dedicated VPC."
  type        = string
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the single public subnet."
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone that contains the single MVP subnet."
  type        = string
}

variable "tags" {
  description = "Mandatory and optional tags supplied by the environment root."
  type        = map(string)
}
