# Nothing environment-specific has a default here: every such value is set
# visibly in terraform.tfvars. Defaults live in the modules.

# General
variable "region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
}

# EC2
variable "instance_name" {
  description = "Name prefix for the instance's IAM role and instance profile"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "metadata_hop_limit" {
  description = "IMDS hop limit: 1 for a plain host, 2 when containers on it must reach the instance role (Docker)"
  type        = number
}

variable "elastic_ip" {
  description = "Attach an Elastic IP so the public address survives a stop/start"
  type        = bool
}

variable "docker_host" {
  description = "First-boot setup for a Docker host behind nginx with SSH deploys, or null for a plain instance. See references/docker-host.md."
  type = object({
    proxy_sites          = map(number)
    deploy_public_key    = string
    deploy_user          = optional(string)
    working_dir_name     = optional(string)
    swap_size_gb         = optional(number)
    client_max_body_size = optional(string)
    docker_apt_codename  = optional(string)
  })
  default = null
}

# Security group
variable "security_group_name" {
  description = "Security group name"
  type        = string
}

variable "security_group_description" {
  description = "Security group description"
  type        = string
}

variable "ingress_rules" {
  description = "Security group ingress rules"
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
}

variable "egress_rules" {
  description = "Security group egress rules"
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
}
