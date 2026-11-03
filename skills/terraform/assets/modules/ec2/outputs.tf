output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.instance.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.instance.private_ip
}

output "public_ip" {
  description = "Public IP address of the EC2 instance: the Elastic IP when one is attached, otherwise the address the subnet assigned, if any"
  value       = var.elastic_ip ? aws_eip.instance[0].public_ip : aws_instance.instance.public_ip
}
