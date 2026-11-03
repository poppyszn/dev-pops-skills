data "aws_vpc" "default" {
  default = true
}

module "security_group" {
  source = "../../modules/security_group"

  name          = var.security_group_name
  description   = var.security_group_description
  vpc_id        = data.aws_vpc.default.id
  ingress_rules = var.ingress_rules
  egress_rules  = var.egress_rules

  tags = var.tags
}

# Optional first-boot setup for a host that runs Docker behind nginx. Off when
# docker_host is null. Unset fields are passed as null so the module's own
# validated defaults apply.
module "docker_host_user_data" {
  count  = var.docker_host == null ? 0 : 1
  source = "../../modules/docker_host_user_data"

  proxy_sites          = var.docker_host.proxy_sites
  deploy_public_key    = var.docker_host.deploy_public_key
  deploy_user          = var.docker_host.deploy_user
  working_dir_name     = var.docker_host.working_dir_name
  swap_size_gb         = var.docker_host.swap_size_gb
  client_max_body_size = var.docker_host.client_max_body_size
  docker_apt_codename  = var.docker_host.docker_apt_codename
}

module "ec2" {
  source = "../../modules/ec2"

  name                   = var.instance_name
  instance_type          = var.instance_type
  metadata_hop_limit     = var.metadata_hop_limit
  elastic_ip             = var.elastic_ip
  user_data              = one(module.docker_host_user_data[*].user_data)
  vpc_security_group_ids = [module.security_group.security_group_id]

  tags = var.tags
}
