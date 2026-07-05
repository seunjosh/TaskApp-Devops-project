provider "aws" {
  region = var.aws_region
}

module "network" {
  source       = "./modules/network"
  project_name = var.project_name
}

module "security_group" {
  source           = "./modules/security_group"
  project_name     = var.project_name
  vpc_id           = module.network.vpc_id
  ssh_allowed_cidr = var.ssh_allowed_cidr
}

module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  ami_id            = var.ami_id
  instance_type     = var.instance_type
  key_name          = var.key_name
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.security_group.k3s_sg_id
}
