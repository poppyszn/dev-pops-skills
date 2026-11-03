# Renders the user data for a Docker host: a settings block followed by
# docker-host.sh. It creates no resources; pass the `user_data` output to the
# ec2 module. Every value is validated in variables.tf so that none can break
# out of the quotes it is written inside.

locals {
  sites = join(" ", [for host, port in var.proxy_sites : "${host}=${port}"])

  # Quoted heredoc: nothing in it is expanded by the shell.
  settings = <<-EOT
    #!/bin/bash
    set -euo pipefail
    install -d -m 755 /etc/docker-host
    cat > /etc/docker-host/bootstrap.env << 'SETTINGS'
    PROXY_SITES="${local.sites}"
    DEPLOY_USER="${var.deploy_user}"
    DEPLOY_PUBLIC_KEY="${var.deploy_public_key}"
    WORKING_DIR_NAME="${var.working_dir_name}"
    SWAP_SIZE_GB="${var.swap_size_gb}"
    CLIENT_MAX_BODY_SIZE="${var.client_max_body_size}"
    DOCKER_APT_CODENAME="${var.docker_apt_codename}"
    SETTINGS
  EOT
}
