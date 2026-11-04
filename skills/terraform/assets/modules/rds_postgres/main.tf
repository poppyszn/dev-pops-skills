resource "aws_db_subnet_group" "this" {
  name       = var.name
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.username
  # RDS creates and rotates the master password in Secrets Manager; it never
  # appears in the configuration or the state.
  manage_master_user_password = true

  storage_type          = "gp3"
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : null
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  backup_retention_period    = var.backup_retention_period
  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"

  tags = merge(var.tags, { Name = var.name })
}

# RDS-managed secrets are rotated every 7 days unless rotation is switched off
# through this resource (documented in the aws_db_instance guide). Referencing the
# instance's secret ARN orders it after the instance exists. Only the "off" state is
# managed: removing this resource later does not turn rotation back on.
resource "aws_secretsmanager_secret_rotation" "master_user_password" {
  count = var.rotate_master_user_password ? 0 : 1

  secret_id        = aws_db_instance.this.master_user_secret[0].secret_arn
  rotation_enabled = false
}
