variable "name" {
  description = "Security group name"
  type        = string
  default     = "allow_tls"
}

variable "description" {
  description = "Security group description"
  type        = string
  default     = "Allow TLS inbound traffic and all outbound traffic"
}

variable "vpc_id" {
  description = "ID of the VPC to create the security group in"
  type        = string
}

variable "ingress_rules" {
  description = "Ingress rules. No inbound traffic is allowed by default."
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for rule in values(var.ingress_rules) :
      length([for source in [rule.cidr_ipv4, rule.cidr_ipv6, rule.referenced_security_group_id] : source if source != null]) == 1
    ])
    error_message = "Each ingress rule must set exactly one of cidr_ipv4, cidr_ipv6 or referenced_security_group_id."
  }
}

variable "egress_rules" {
  description = "Egress rules. Defaults to allow all traffic; override to restrict."
  type = map(object({
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
    from_port                    = optional(number)
    to_port                      = optional(number)
    ip_protocol                  = string
  }))
  default = {
    allow_all_ipv4 = { cidr_ipv4 = "0.0.0.0/0", ip_protocol = "-1" }
    allow_all_ipv6 = { cidr_ipv6 = "::/0", ip_protocol = "-1" }
  }

  validation {
    condition = alltrue([
      for rule in values(var.egress_rules) :
      length([for source in [rule.cidr_ipv4, rule.cidr_ipv6, rule.referenced_security_group_id] : source if source != null]) == 1
    ])
    error_message = "Each egress rule must set exactly one of cidr_ipv4, cidr_ipv6 or referenced_security_group_id."
  }
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
