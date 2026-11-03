output "instance_id" {
  description = "ID of the EC2 instance"
  value       = module.ec2.instance_id
}

output "public_ip" {
  description = "Public IP address of the EC2 instance, if assigned"
  value       = module.ec2.public_ip
}

output "security_group_id" {
  description = "ID of the security group"
  value       = module.security_group.security_group_id
}
