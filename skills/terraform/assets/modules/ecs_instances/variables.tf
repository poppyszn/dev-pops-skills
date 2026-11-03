variable "name" {
  description = "Name prefix for the instance role, launch template and Auto Scaling group"
  type        = string
}

variable "cluster_name" {
  description = "Name of the ECS cluster the instances join"
  type        = string
}

variable "ami_ssm_parameter_name" {
  description = "SSM parameter holding the ECS-optimized AMI ID"
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2023/recommended/image_id" # ECS-optimized Amazon Linux 2023, x86_64
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "subnet_ids" {
  description = "Subnets the Auto Scaling group launches instances into"
  type        = list(string)
}

variable "vpc_security_group_ids" {
  description = "IDs of the security groups to associate"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances"
  type        = number
  default     = 4
}

variable "root_block_device_encrypted" {
  description = "Enable encryption for root block device"
  type        = bool
  default     = true
}

variable "root_block_device_volume_size" {
  description = "Root block device volume size in GiB (the ECS-optimized AMI snapshot is 30 GiB)"
  type        = number
  default     = 30
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

variable "tags" {
  description = "Tags for resource"
  type        = map(string)
  default     = {}
}
