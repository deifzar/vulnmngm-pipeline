variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for decrypting secrets"
  type        = string
}

variable "secrets_prefix" {
  description = "Prefix for Secrets Manager secret paths (e.g., 'devsecops' allows access to 'devsecops/*')"
  type        = string
  default     = "devsecops"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}