variable "name" {
  description = "Name prefix for the IAM role and instance profile"
  type        = string
}

variable "ami_ssm_parameter_name" {
  description = "SSM parameter holding the AMI ID"
  type        = string
  default     = "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id" # Canonical Ubuntu 26.04 LTS, amd64
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "root_block_device_encrypted" {
  description = "Enable encryption for root block device"
  type        = bool
  default     = true
}

variable "root_block_device_volume_size" {
  description = "Root block device volume size in GiB"
  type        = number
  default     = 8
}

variable "root_block_device_volume_type" {
  description = "Root block device EBS volume type"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["standard", "gp2", "gp3", "io1", "io2", "sc1", "st1"], var.root_block_device_volume_type)
    error_message = "root_block_device_volume_type must be one of: standard, gp2, gp3, io1, io2, sc1, st1."
  }
}

variable "metadata_hop_limit" {
  description = "IMDS PUT response hop limit. 1 for a plain host; 2 when containers on the host must reach the instance role's credentials (Docker)."
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 2
    error_message = "metadata_hop_limit must be 1 or 2. A larger value lets requests relayed through more hops (a reverse proxy, an SSRF) reach the metadata service."
  }
}

variable "user_data" {
  description = "Script run once on first boot (cloud-init), or null for none. Up to 16 KB."
  type        = string
  default     = null

  validation {
    condition     = var.user_data == null || length(var.user_data) <= 16384
    error_message = "user_data must be at most 16384 bytes before encoding."
  }
}

variable "elastic_ip" {
  description = "Attach an Elastic IP so the public address survives a stop/start"
  type        = bool
  default     = false
}

variable "vpc_security_group_ids" {
  description = "IDs of the security groups to associate"
  type        = list(string)
}

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
