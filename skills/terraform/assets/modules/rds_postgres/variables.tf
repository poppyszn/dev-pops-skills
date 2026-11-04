variable "name" {
  description = "DB instance identifier and name prefix for the subnet group"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets (at least two Availability Zones) for the DB subnet group"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "RDS needs subnets in at least two Availability Zones."
  }
}

variable "vpc_security_group_ids" {
  description = "Security groups attached to the instance"
  type        = list(string)
}

variable "instance_class" {
  description = "DB instance class"
  type        = string
  default     = "db.t4g.micro"
}

variable "engine_version" {
  description = "PostgreSQL version. A major version (\"17\") lets AWS pick the minor release; minor upgrades are applied automatically."
  type        = string
  default     = "17"
}

variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "username" {
  description = "Master username. The password is generated and kept in Secrets Manager, never in state or tfvars."
  type        = string
  default     = "postgres"
}

variable "allocated_storage" {
  description = "Initial storage in GiB (gp3)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Storage autoscaling ceiling in GiB; 0 disables autoscaling"
  type        = number
  default     = 100
}

variable "publicly_accessible" {
  description = "Give the instance a public IP so its endpoint resolves publicly. Access is still limited by the security group, which must allow only known addresses."
  type        = bool
  default     = false
}

variable "multi_az" {
  description = "Run a standby in a second Availability Zone"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Days to keep automated backups (0 disables them)"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_period >= 0 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 0 and 35."
  }
}

variable "deletion_protection" {
  description = "Block deletion of the instance. On in production."
  type        = bool
}

variable "skip_final_snapshot" {
  description = "Skip the final snapshot on destroy. False in production."
  type        = bool
}

variable "rotate_master_user_password" {
  description = "Let Secrets Manager rotate the managed master password (AWS default: every 7 days). Set false to turn rotation off while keeping the secret."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
