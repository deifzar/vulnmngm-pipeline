variable "instance_name" {
  description = "Identifier for the RDS instance"
  type        = string
}

# =============================================================================
# Engine Configuration
# =============================================================================
variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "14.10"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Maximum storage for autoscaling in GB (0 to disable)"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type (gp2, gp3, io1)"
  type        = string
  default     = "gp3"
}

# =============================================================================
# Database Configuration
# =============================================================================
variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "admin_username" {
  description = "Administrator username"
  type        = string
  default     = "dbadmin"
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

# =============================================================================
# Network Configuration
# =============================================================================
variable "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

# =============================================================================
# Encryption
# =============================================================================
variable "kms_key_arn" {
  description = "KMS key ARN for encryption at rest"
  type        = string
}

# =============================================================================
# Backup Configuration
# =============================================================================
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on deletion (set to false for production)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

# =============================================================================
# Monitoring & Logging
# =============================================================================
variable "enable_performance_insights" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "cloudwatch_log_exports" {
  description = "List of log types to export to CloudWatch"
  type        = list(string)
  default     = ["postgresql", "upgrade"]
}

variable "cloudwatch_log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "create_parameter_group" {
  description = "Create custom parameter group with logging enabled"
  type        = bool
  default     = true
}

# =============================================================================
# Tags
# =============================================================================
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}