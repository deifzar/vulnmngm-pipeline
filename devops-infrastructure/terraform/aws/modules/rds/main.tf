# =============================================================================
# RDS PostgreSQL Instance
# =============================================================================
resource "aws_db_instance" "postgresql" {
  identifier = var.instance_name

  # Engine configuration
  engine               = "postgres"
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type         = var.storage_type

  # Database configuration
  db_name  = var.database_name
  username = var.admin_username
  password = var.admin_password
  port     = 5432

  # Network configuration
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false
  multi_az               = var.multi_az

  # Encryption at rest
  storage_encrypted = true
  kms_key_id        = var.kms_key_arn

  # Backup configuration
  backup_retention_period = var.backup_retention_days
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window
  copy_tags_to_snapshot   = true
  delete_automated_backups = false
  skip_final_snapshot     = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.instance_name}-final-snapshot"

  # Performance Insights (optional monitoring)
  performance_insights_enabled          = var.enable_performance_insights
  performance_insights_retention_period = var.enable_performance_insights ? 7 : null
  performance_insights_kms_key_id       = var.enable_performance_insights ? var.kms_key_arn : null

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = var.cloudwatch_log_exports

  # Parameter group (optional custom settings)
  parameter_group_name = var.create_parameter_group ? aws_db_parameter_group.postgresql[0].name : null

  # Other settings
  auto_minor_version_upgrade = true
  deletion_protection        = var.deletion_protection

  tags = merge(var.tags, {
    Name = var.instance_name
  })
}

# =============================================================================
# Parameter Group (optional - for custom PostgreSQL settings)
# =============================================================================
resource "aws_db_parameter_group" "postgresql" {
  count = var.create_parameter_group ? 1 : 0

  name   = "${var.instance_name}-params"
  family = "postgres${split(".", var.engine_version)[0]}"

  description = "Custom parameter group for ${var.instance_name}"

  # Example parameters - adjust as needed
  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_duration"
    value = "1"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = merge(var.tags, {
    Name = "${var.instance_name}-params"
  })
}

# =============================================================================
# CloudWatch Log Group for RDS logs
# =============================================================================
resource "aws_cloudwatch_log_group" "postgresql" {
  for_each = toset(var.cloudwatch_log_exports)

  name              = "/aws/rds/instance/${var.instance_name}/${each.value}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.tags, {
    Name = "${var.instance_name}-${each.value}-logs"
  })
}