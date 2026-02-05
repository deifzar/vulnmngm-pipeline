variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "spaincentral"
}

variable "allowed_ssh_source_ips" {
  description = "List of IPs allowed for SSH access"
  type        = list(string)
  # Note: Not marked sensitive because IPs are used in for_each and
  # will be visible in Azure Portal anyway
}

variable "allowed_https_source_ips" {
  description = "List of IPs allowed for HTTPS access"
  type        = list(string)
  # Note: Not marked sensitive because IPs are used in for_each and
  # will be visible in Azure Portal anyway
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "/path/to/sshkey.pub"
}

variable "postgresql_admin_password" {
  description = "PostgreSQL admin password for SonarQube DB"
  type        = string
  sensitive   = true
}

variable "enable_bastion" {
  description = "Whether to deploy Azure Bastion"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "staging"
    ManagedBy   = "Terraform"
    Project     = "CPTM8"
    Owner       = "DevSecOps Team"
  }
}
