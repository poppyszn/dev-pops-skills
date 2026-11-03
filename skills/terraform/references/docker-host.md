# Docker host: an EC2 instance that runs compose behind nginx, deployed over SSH

Assets: `assets/modules/docker_host_user_data` (with `docker-host.sh`), plus the `ec2` module's `metadata_hop_limit`, `elastic_ip` and `user_data` options. Wired into `assets/environments/ec2/` through the optional `docker_host` variable.

This is the host shape the `cicd` skill's production deploy expects: Docker with the Compose plugin, `git`, `jq`, a deploy user that GitHub Actions logs into over SSH, and nginx terminating TLS in front of containers that listen on `127.0.0.1` only. The plain `ec2` template stays Session-Manager-only; this is the opt-in for projects that deploy over SSH.

## Turning it on

In each environment's `terraform.tfvars` (production shown; the others set their own hostnames and key, or stay `null`):

```hcl
metadata_hop_limit = 2          # containers must reach the instance role (see below)
elastic_ip         = true       # DNS A records need an address that survives a stop/start

docker_host = {
  proxy_sites       = { "api.example.com" = 3000, "example.com" = 3001 }  # hostname => container port on 127.0.0.1
  deploy_public_key = "ssh-ed25519 AAAA... deploy@<PROJECT>-production"   # public half only
}
```

Add one SSH rule to `ingress_rules`. Never `0.0.0.0/0` unless the user accepts it explicitly:

```hcl
ssh = { referenced_security_group_id = "<BASTION_SECURITY_GROUP_ID>", from_port = 22, to_port = 22, ip_protocol = "tcp" }
```

Every other `docker_host` field is optional and falls back to the module default:

| Field | Default | Meaning |
|---|---|---|
| `deploy_user` | `deploy` | Login name. Joins the `docker` group (root-equivalent) and gets no sudo. |
| `working_dir_name` | `apps` | Directory under the deploy user's home; the `WORKING_DIR` secret is its full path. |
| `swap_size_gb` | `4` | Swap file, a safety net against OOM kills on a small instance. `0` disables it. |
| `client_max_body_size` | `20m` | nginx upload limit for every site. |
| `docker_apt_codename` | host's own | Only for a brand-new Ubuntu release Docker has no apt repository for yet; the script stops with a clear message if the repository is missing. |

## This is an exception to "no SSH", and why

The templates default to Session Manager with no port 22. A GitHub-hosted runner has no fixed address, so "SSH only from your address" cannot be applied to it: the realistic options are a bastion (the deploy's `SSH_JUMP_HOST`), a wide rule, or not using SSH. This template keeps the proven SSH deploy with its mitigations: key-only logins, no root login, fail2ban, pinned host keys in CI (`SSH_KNOWN_HOSTS`, strict checking), a deploy user with no sudo, and a security group that opens 22 to a bastion rather than the internet. Deploying through SSM Run Command instead would remove port 22 and the key entirely; it is not templated yet (see `roadmap.md`).

## IMDS hop limit 2

The instance enforces IMDSv2. The hop limit is how many network hops the token response may travel. At 1, a process in a container on Docker's bridge network is one hop too far, so an AWS SDK inside the container cannot get the instance role's credentials (AWS: "in a container environment, a hop limit of 1 can cause issues", and suggests 2). An API that uploads to S3 through the instance role needs `metadata_hop_limit = 2`. Keep IMDSv2 required. If uploads fail with a credentials error from inside the container while `aws sts get-caller-identity` works on the host, check this first:

```bash
aws ec2 describe-instances --instance-ids <ID> --query 'Reservations[].Instances[].MetadataOptions'
```

## What `docker-host.sh` does

Security updates with unattended-upgrades; fail2ban for sshd; an optional swap file; the deploy user with the public key from the settings; key-only sshd with no root login (`01-hardening.conf`, the `01-` prefix because sshd keeps the first value it reads); Docker Engine and the Compose plugin from Docker's apt repository with container log rotation; nginx and certbot with one reverse-proxy site per `proxy_sites` entry in `/etc/nginx/conf.d/`. Output goes to `/var/log/docker-host-bootstrap.log`; `/var/lib/docker-host-bootstrap.done` marks success.

Two differences from hand-written versions of this script, on purpose:

- **Only the public key is on the host.** Earlier versions generated the key pair on the host and left the private key in the deploy user's `.ssh/`, to be copied out once. Generate the pair on your own machine instead; nothing secret is ever on the host or in the user data.
- **User data runs once.** The `ec2` module ignores later edits to `user_data`: changing the script in Terraform does not re-run it, and replacing a production host for it should be a decision. To change a running host, run the change by hand (or replace the instance deliberately, which is a confirmation).

Without Terraform, create `/etc/docker-host/bootstrap.env` with `PROXY_SITES="host=port host=port"`, `DEPLOY_USER`, `DEPLOY_PUBLIC_KEY`, and optionally `WORKING_DIR_NAME`, `SWAP_SIZE_GB`, `CLIENT_MAX_BODY_SIZE`, `DOCKER_APT_CODENAME`, then run `docker-host.sh` as root.

## After first boot

1. **Generate the deploy key before the first apply**, on your machine: `ssh-keygen -t ed25519 -N '' -C deploy@<PROJECT>-production -f deploy_key`. Put `deploy_key.pub` in `docker_host.deploy_public_key`. Put the contents of `deploy_key` in the GitHub environment secret `SSH_PRIVATE_KEY`, then delete both local files.
2. **Wait for the bootstrap to finish.** Reach the host with `aws ssm start-session --target <instance_id>` (the instance role includes Session Manager) or SSH, and check `test -f /var/lib/docker-host-bootstrap.done`. If it is missing, read `/var/log/docker-host-bootstrap.log`.
3. **Pin the host key.** From your machine run `ssh-keyscan -p 22 <elastic-ip>` and compare the fingerprints with the ones the log printed (`ssh-keygen -lf -` on the scan output). Store the scan output as the secret `SSH_KNOWN_HOSTS` (plus the bastion's, if one is used).
4. **DNS.** Create an A record to the Elastic IP for each `proxy_sites` hostname.
5. **Certificates.** Once DNS resolves, on the host: `sudo certbot --nginx -d <hostname>` for each site. certbot adds the 443 server and the HTTP to HTTPS redirect; renewal runs from `certbot.timer`. Check it with `sudo certbot renew --dry-run`.
6. **Create the application's `.env`** at `<WORKING_DIR>/<repo>/docker/production/.env` from `.env.example` and fill in real values. The production deploy never creates it and its preflight stops if it is missing or still has `<placeholder>` values.
7. **Run the first deploy** (the `cicd` skill's production workflow).

## Security group

Open only 80 and 443 to the world, and 22 to the bastion or listed addresses. The containers publish on `127.0.0.1` (see the `docker` skill's production compose), so ports 3000 and 3001 are not reachable even if a rule is added by mistake. There is no host firewall: the security group is the only firewall, so review its plan carefully.

## Not covered

More than one host, a load balancer, a private subnet or a managed database. The `ecs` template covers a load-balanced service; anything else follows `references/module-standard.md`.
