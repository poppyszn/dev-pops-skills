variable "proxy_sites" {
  description = "Public hostname => local port of the container nginx proxies it to, e.g. { \"api.example.com\" = 3000 }. The container must publish that port on 127.0.0.1."
  type        = map(number)

  validation {
    condition     = length(var.proxy_sites) > 0
    error_message = "proxy_sites needs at least one hostname."
  }

  validation {
    condition     = alltrue([for host in keys(var.proxy_sites) : can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", host))])
    error_message = "Every proxy_sites key must be a lowercase hostname such as api.example.com."
  }

  validation {
    condition     = alltrue([for port in values(var.proxy_sites) : port >= 1024 && port <= 65535 && floor(port) == port])
    error_message = "Every proxy_sites port must be an integer from 1024 to 65535."
  }
}

variable "deploy_user" {
  description = "Login name GitHub Actions deploys as. It joins the docker group and gets no sudo."
  type        = string
  default     = "deploy"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.deploy_user)) && var.deploy_user != "root"
    error_message = "deploy_user must be a valid lowercase Linux user name and not root."
  }
}

variable "deploy_public_key" {
  description = "Public half of the deploy key (the private half goes in the GitHub environment secret SSH_PRIVATE_KEY and never touches this host)"
  type        = string

  validation {
    condition     = can(regex("^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521)) [A-Za-z0-9+/]+={0,3}( [A-Za-z0-9@._-]+)?$", var.deploy_public_key))
    error_message = "deploy_public_key must be one OpenSSH public key line (ssh-ed25519 AAAA... optional-comment) with no quotes or line breaks."
  }
}

variable "working_dir_name" {
  description = "Directory under the deploy user's home where the deploy clones the repository. Must match the WORKING_DIR secret."
  type        = string
  default     = "apps"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.working_dir_name))
    error_message = "working_dir_name must be a single directory name: letters, digits, dot, underscore and hyphen."
  }
}

variable "swap_size_gb" {
  description = "Swap file size in GiB, or 0 for none"
  type        = number
  default     = 4
  nullable    = false

  validation {
    condition     = var.swap_size_gb >= 0 && var.swap_size_gb <= 64 && floor(var.swap_size_gb) == var.swap_size_gb
    error_message = "swap_size_gb must be a whole number from 0 to 64."
  }
}

variable "client_max_body_size" {
  description = "nginx client_max_body_size for every proxied site (the largest upload the API accepts)"
  type        = string
  default     = "20m"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]?$", var.client_max_body_size))
    error_message = "client_max_body_size must be a number with an optional k, m or g suffix, e.g. 20m."
  }
}

variable "docker_apt_codename" {
  description = "Ubuntu codename to use for Docker's apt repository, or empty to use the host's own. Set it only when Docker has not published a repository for a brand-new Ubuntu release yet."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]*$", var.docker_apt_codename))
    error_message = "docker_apt_codename must be lowercase letters only, e.g. noble."
  }
}
