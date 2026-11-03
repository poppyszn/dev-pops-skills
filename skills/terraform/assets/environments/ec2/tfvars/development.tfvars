# ---------------------------------------------------------------------------
# General
# ---------------------------------------------------------------------------
region = "eu-west-1" # <REGION>: set here on purpose, there is no default in variables.tf

tags = {
  Project     = "<PROJECT>"
  Environment = "development"
}

# ---------------------------------------------------------------------------
# EC2
# ---------------------------------------------------------------------------
instance_name = "<PROJECT>-development"
instance_type = "t3.micro"

# IMDS hop limit. Keep 1 for a plain host. Set 2 on a host that runs Docker, or the
# containers cannot reach the instance role's credentials. See references/docker-host.md.
metadata_hop_limit = 1

# A fixed public address that survives a stop/start (needed for a DNS A record).
elastic_ip = false

# Docker host with nginx and SSH deploys: null leaves a plain instance. To turn it
# on, replace null with the block below (references/docker-host.md explains each
# value) and add an SSH ingress rule below.
#
# docker_host = {
#   proxy_sites       = { "<API_DOMAIN>" = 3000 }                 # hostname => local port
#   deploy_public_key = "ssh-ed25519 AAAA... deploy@<PROJECT>-development" # public half only
# }
docker_host = null

# ---------------------------------------------------------------------------
# Security group
# No SSH rule by default: the instance is reached through Session Manager. A Docker
# host deployed over SSH (docker_host above) adds one, from a bastion's security
# group or from listed addresses, never from 0.0.0.0/0. See references/docker-host.md:
#   ssh = { referenced_security_group_id = "<BASTION_SECURITY_GROUP_ID>", from_port = 22, to_port = 22, ip_protocol = "tcp" }
# ---------------------------------------------------------------------------
security_group_name        = "<PROJECT>-development-instance-SG"
security_group_description = "Allow HTTP and HTTPS inbound traffic and all IPv4 outbound traffic"

ingress_rules = {
  http  = { cidr_ipv4 = "0.0.0.0/0", from_port = 80, to_port = 80, ip_protocol = "tcp" }
  https = { cidr_ipv4 = "0.0.0.0/0", from_port = 443, to_port = 443, ip_protocol = "tcp" }
}

egress_rules = {
  allow_all_ipv4 = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" }
}
