# Bootstrap for a single Docker host: security updates, fail2ban, swap, a deploy
# user that GitHub Actions logs in as, hardened sshd, Docker Engine with the
# Compose plugin, and nginx + certbot in front of the containers.
#
# Runs once as root on first boot (cloud-init). Settings come from
# /etc/docker-host/bootstrap.env, which the Terraform module writes ahead of this
# script. To use it without Terraform, create that file with the same keys (see
# references/docker-host.md) and run this script as root.
#
# Ubuntu Server LTS, amd64 or arm64. No host firewall: the security group is the
# firewall. Output goes to /var/log/docker-host-bootstrap.log, and
# /var/lib/docker-host-bootstrap.done marks success.
set -euo pipefail

exec > >(tee -a /var/log/docker-host-bootstrap.log) 2>&1
echo "=== bootstrap started $(date -u +%FT%TZ) ==="

SETTINGS=/etc/docker-host/bootstrap.env
[ -r "$SETTINGS" ] || { echo "missing $SETTINGS" >&2; exit 1; }
# shellcheck disable=SC1090
. "$SETTINGS"

: "${PROXY_SITES:?PROXY_SITES is required (space-separated host=port pairs)}"
: "${DEPLOY_USER:?DEPLOY_USER is required}"
: "${DEPLOY_PUBLIC_KEY:?DEPLOY_PUBLIC_KEY is required}"
WORKING_DIR_NAME="${WORKING_DIR_NAME:-apps}"
SWAP_SIZE_GB="${SWAP_SIZE_GB:-4}"
CLIENT_MAX_BODY_SIZE="${CLIENT_MAX_BODY_SIZE:-20m}"
DOCKER_APT_CODENAME="${DOCKER_APT_CODENAME:-}"

export DEBIAN_FRONTEND=noninteractive
# Apply service restarts after upgrades automatically instead of prompting.
export NEEDRESTART_MODE=a

# ---------------------------------------------------------------- updates
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  ca-certificates curl gnupg git jq unattended-upgrades fail2ban
# Security updates install themselves from here on.
systemctl enable --now unattended-upgrades

# ---------------------------------------------------------------- swap
# A safety net against OOM kills on a small instance, not extra capacity:
# EBS-backed swap is far slower than RAM. Skipped when disabled, when swap
# already exists, or when the disk cannot leave 5 GiB free after the file.
if [ "$SWAP_SIZE_GB" -gt 0 ]; then
  if swapon --show=NAME --noheadings | grep -q .; then
    echo "Swap already configured; skipping."
  else
    avail_gb=$(df --output=avail -BG / | tail -n 1 | tr -dc '0-9')
    if [ "$avail_gb" -lt $((SWAP_SIZE_GB + 5)) ]; then
      echo "WARNING: only ${avail_gb}G free on /; skipping ${SWAP_SIZE_GB}G swap file."
    else
      fallocate -l "${SWAP_SIZE_GB}G" /swapfile
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
  fi
  # Prefer RAM: swap only under real pressure. Keep the filesystem cache a
  # little longer.
  cat > /etc/sysctl.d/99-docker-host-memory.conf << 'EOF'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF
  sysctl -p /etc/sysctl.d/99-docker-host-memory.conf
fi

# ---------------------------------------------------------------- deploy user
# The `docker` group is root-equivalent, and the deploy user needs it to run
# compose. It gets no sudo.
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$DEPLOY_USER"
fi
# Locked password: key login only.
passwd -l "$DEPLOY_USER" || true

DEPLOY_HOME=$(getent passwd "$DEPLOY_USER" | cut -d: -f6)
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$DEPLOY_HOME/.ssh"

# Only the PUBLIC half of the deploy key is ever on this host. Generate the pair
# on your own machine (ssh-keygen -t ed25519), put the public key in the settings
# and the private key in the GitHub `production` environment secret SSH_PRIVATE_KEY.
touch "$DEPLOY_HOME/.ssh/authorized_keys"
if ! grep -qxF "$DEPLOY_PUBLIC_KEY" "$DEPLOY_HOME/.ssh/authorized_keys"; then
  echo "$DEPLOY_PUBLIC_KEY" >> "$DEPLOY_HOME/.ssh/authorized_keys"
fi
chown "$DEPLOY_USER:$DEPLOY_USER" "$DEPLOY_HOME/.ssh/authorized_keys"
chmod 600 "$DEPLOY_HOME/.ssh/authorized_keys"

# Matches the WORKING_DIR secret.
install -d -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$DEPLOY_HOME/$WORKING_DIR_NAME"

# ---------------------------------------------------------------- sshd
# Key-only logins, no root. The 01- prefix matters: sshd keeps the first value
# it reads, and cloud-init's 50-cloud-init.conf would otherwise win.
cat > /etc/ssh/sshd_config.d/01-hardening.conf << 'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin no
EOF
sshd -t
systemctl reload ssh

# ---------------------------------------------------------------- fail2ban
cat > /etc/fail2ban/jail.d/sshd.local << 'EOF'
[DEFAULT]
bantime  = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
backend = systemd
EOF
systemctl enable --now fail2ban
systemctl restart fail2ban

# ---------------------------------------------------------------- docker
# Docker publishes an apt repository per Ubuntu release, and a new release can
# appear there later than on Ubuntu. Fail with a clear message instead of an
# apt error: set DOCKER_APT_CODENAME to an older codename that exists.
# shellcheck disable=SC1091
. /etc/os-release
codename="${DOCKER_APT_CODENAME:-$VERSION_CODENAME}"
if ! curl -fsI "https://download.docker.com/linux/ubuntu/dists/${codename}/Release" >/dev/null; then
  echo "Docker has no apt repository for Ubuntu '${codename}'. Set DOCKER_APT_CODENAME to one that exists (https://download.docker.com/linux/ubuntu/dists/)." >&2
  exit 1
fi
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable" \
  > /etc/apt/sources.list.d/docker.list
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Rotate container logs so a chatty container cannot fill the disk.
install -d -m 755 /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" }
}
EOF
systemctl enable docker
systemctl restart docker
usermod -aG docker "$DEPLOY_USER"

# ---------------------------------------------------------------- nginx + certbot
apt-get install -y nginx certbot python3-certbot-nginx
systemctl enable nginx
# The apt package installs and enables certbot.timer for renewals.
systemctl enable --now certbot.timer
rm -f /etc/nginx/sites-enabled/default

# The containers' ports are published on 127.0.0.1 only; nginx on 80/443 is the
# only public entry point, so the security group opens just those (and 22 for
# the deploy). Certbot adds the 443 server and the HTTP->HTTPS redirect when you
# run it (see references/docker-host.md, "After first boot").
write_site() {
  local domain="$1" upstream_port="$2" file="/etc/nginx/conf.d/$1.conf"
  cat > "$file" << EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${domain};

  # Uploads through the API; raise if it accepts larger files.
  client_max_body_size ${CLIENT_MAX_BODY_SIZE};

  location / {
    proxy_pass http://127.0.0.1:${upstream_port};
    proxy_http_version 1.1;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_read_timeout 60s;
  }
}
EOF
}

for entry in $PROXY_SITES; do
  write_site "${entry%%=*}" "${entry##*=}"
done
nginx -t
systemctl reload nginx

# ---------------------------------------------------------------- done
echo "SSH host key fingerprints (compare with: ssh-keyscan <host> | ssh-keygen -lf -):"
for key in /etc/ssh/ssh_host_*_key.pub; do
  ssh-keygen -lf "$key"
done
if [ -f /var/run/reboot-required ]; then
  echo "NOTE: a reboot is pending (kernel update). Reboot when convenient."
fi
touch /var/lib/docker-host-bootstrap.done
echo "=== bootstrap finished $(date -u +%FT%TZ) ==="
