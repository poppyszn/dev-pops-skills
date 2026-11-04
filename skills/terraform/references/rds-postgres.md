# RDS PostgreSQL module

Assets: `assets/modules/rds_postgres`, `assets/modules/security_group`.

One PostgreSQL instance (default `db.t4g.micro`) with a DB subnet group. The security group comes from the `security_group` module, wired in the environment's `main.tf`. Copy both modules (see `references/layout.md`). Nothing else is created: no VPC, no parameter group, no monitoring role.

## Wiring in an environment

Use the default VPC unless the project has its own, and give the module blocks names that say what the database is for. A second database later must not collide with the first.

```hcl
data "aws_vpc" "default" { default = true }

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "<PURPOSE>_postgres_db_security_group" {
  source        = "../../modules/security_group"
  name          = var.security_group_name
  description   = var.security_group_description
  vpc_id        = data.aws_vpc.default.id
  ingress_rules = var.ingress_rules
  egress_rules  = {} # a database initiates no outbound traffic
  tags          = var.tags
}

module "<PURPOSE>_postgres_db" {
  source                 = "../../modules/rds_postgres"
  name                   = var.db_identifier
  subnet_ids             = data.aws_subnets.default.ids
  vpc_security_group_ids = [module.<PURPOSE>_postgres_db_security_group.security_group_id]
  # …remaining inputs from variables.tf, values from terraform.tfvars
}
```

`ingress_rules = {}` means nobody can connect. Open the Postgres port to an application's security group, never to `0.0.0.0/0`:
`app = { referenced_security_group_id = "sg-…", from_port = 5432, to_port = 5432, ip_protocol = "tcp" }`.

## What the module does and why

- **Password never in configuration or state.** `manage_master_user_password = true`: RDS creates the master password in Secrets Manager. The provider rejects it together with `password` or `password_wo`. The module outputs the secret's ARN, not its value.
- **Secrets Manager rotates that password** (every 7 days by default), so applications must read the secret at runtime rather than copy the password once. To switch rotation off while keeping the managed secret, set `rotate_master_user_password = false`: the module then manages an `aws_secretsmanager_secret_rotation` with `rotation_enabled = false` (the provider's documented method; the secret ARN is taken from the instance so it is ordered after it). Only the "off" state is managed, so setting it back to `true` does not re-enable rotation by itself. A fixed password is a trade-off: say so, and prefer a read-only database user for other tools. The apply role then needs `secretsmanager:CancelRotateSecret`.
- **TLS.** RDS for PostgreSQL 15 and later defaults `rds.force_ssl` to 1 (on); 14 and older default to 0. The module uses the default parameter group, so enforcement relies on AWS's default. Pin it with a parameter group when the instance is public.
- **Engine version is a major prefix** (`"17"`). The provider allows a prefix when `auto_minor_version_upgrade` is on, and the running version is exposed as `engine_version_actual`. Do not add `ignore_changes = [engine_version]`: it hides a deliberate major upgrade (changing `17` to `18` would plan nothing).
- **Storage:** gp3, encrypted, with autoscaling when `max_allocated_storage` is above `allocated_storage`; the provider hides the autoscaling drift on `allocated_storage` by itself.
- **Private by default.** `publicly_accessible` defaults to `false`; the default VPC's subnets are public subnets, so this flag and the empty security group are what keep it private. Setting it to `true` gives the instance a public IP (public IPv4 is billed per hour) and its endpoint resolves publicly; access is then decided only by `ingress_rules`. Opening 5432 to `0.0.0.0/0` goes against the skill's network default: do it only when the user asks, comment why in `terraform.tfvars`, and recommend narrowing it to the client's addresses. For anything beyond a small project, ask whether to add a VPC with private subnets (a new module).
- **Deletion:** `deletion_protection` and `skip_final_snapshot` are required inputs with no default, set per environment. Production: `true` and `false`. `final_snapshot_identifier` is required by the provider whenever `skip_final_snapshot` is `false`; the module derives it as `<name>-final`.

## Cost

Look the prices up, do not quote them from memory: `aws pricing get-products --region us-east-1 --service-code AmazonRDS` with filters on `regionCode`, `instanceType`, `databaseEngine` and `deploymentOption` (instance, per hour), and `volumeType` (storage, per GiB-month); public IPv4 is under `--service-code AmazonVPC`, group `VPCPublicIPv4Address`. Add the Secrets Manager secret (a per-secret monthly price) and note what is left out: data transfer, tax, snapshots kept after deletion, and storage autoscaling up to `max_allocated_storage`. Multi-AZ roughly doubles instance and storage.

## Checks

`terraform validate`, then `plan`: a new database is 3 resources (instance, subnet group, security group) with the endpoint and secret ARN known only after apply. Creating a `db.t4g.micro` takes several minutes. `apply` is a confirmation.
