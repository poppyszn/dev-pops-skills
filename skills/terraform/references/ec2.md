# EC2 template

Assets: `assets/modules/ec2`, `assets/modules/security_group`, `assets/environments/ec2/` (`shared/*.tf`, `tfvars/<env>.tfvars`), plus `assets/environments/common/providers.tf`.

One instance in the default VPC, with a security group. Copy the two modules and the environment files (see `references/layout.md`), then replace the markers in each `terraform.tfvars`: `<PROJECT>` (short, lowercase) and `<REGION>` (keep `eu-west-1` unless told otherwise).

## What the template does and why

- **Session Manager, not SSH.** The module creates an instance role with `AmazonSSMManagedInstanceCore` and attaches it as an instance profile. There is no `key_name`, so a port 22 rule could never be used; the `tfvars` open only 80 and 443. Reach the host with `aws ssm start-session --target <instance_id>`. If the user does want SSH, add a `key_name` variable to the module first, then a rule limited to their address, never `0.0.0.0/0`.
- **IMDSv2 only** (`http_tokens = "required"`) and an **encrypted gp3 root volume**. These are module defaults; keep them. The hop limit is 1 (`metadata_hop_limit`) for a plain host. A host that runs Docker needs 2, or containers cannot reach the instance role's credentials: see `references/docker-host.md`.
- **AMI from an SSM parameter**, `ami_ssm_parameter_name`, default Canonical's `/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id`. No AMI ID is hard-coded, so the module works in any region. The instance has `ignore_changes = [ami]`: the parameter moves on every Canonical release, and replacing a running instance should be a decision, not a side effect of a plan. To move to a new image, change the parameter name or use `terraform apply -replace=...` (a confirmation).
- **Default VPC and subnet** are used, so the instance gets a public IP if the subnet assigns one. For anything beyond a development box, ask the user whether to add a VPC module; that is a new module (see `references/module-standard.md`).

## Before the first plan

Confirm the AMI parameter exists in the target region (read-only, needs credentials):

```bash
aws ssm get-parameter --region <REGION> --name /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id --query Parameter.Value --output text
```

If it does not resolve, find the right path in Canonical's AWS image documentation and update the module default, then record the source in `sources.md`. Do not fall back to a hard-coded ID. As of the last check this path came from Canonical's documentation but was not resolved against a live account (`unverified` in `sources.md`).

## Extending

The module already has opt-in `elastic_ip`, `user_data` (run once, on first boot; later edits are ignored on purpose) and `metadata_hop_limit`. The `ec2` environment kind exposes them as `elastic_ip`, `metadata_hop_limit` and the optional `docker_host` block, which renders the first-boot script for a Docker host behind nginx with SSH deploys: `references/docker-host.md`. A static site beside the instance: `references/static-site.md`.

Extra volumes, an instance in a private subnet: new arguments or a new module, written to `references/module-standard.md`, wired into all three environments.
