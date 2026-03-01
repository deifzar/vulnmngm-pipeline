variable "secret_prefix" {
  description = "Prefix for all secret names (e.g., 'devsecops' creates 'devsecops/github-pat')"
  type        = string
  default     = "devsecops"
}

variable "secrets" {
  description = "Secrets to add"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
