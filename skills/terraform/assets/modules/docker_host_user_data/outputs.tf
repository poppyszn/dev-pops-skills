output "user_data" {
  description = "Settings block followed by docker-host.sh, ready to pass to the ec2 module's user_data"
  value       = join("\n", [local.settings, file("${path.module}/docker-host.sh")])
}
