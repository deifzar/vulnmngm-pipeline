variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "description" {
  description = "Description of the KMS key"
  type        = string
  default     = "DevSecOps infrastructure encryption key"
}

variable "deletion_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction (7-30 days)"
  type        = number
  default     = 30
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "multi_region" {
  description = "Enable multi-region key replication"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}