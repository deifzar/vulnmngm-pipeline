variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "location" {
  description = "AWS region"
  type        = string
  default     = "eu-south-2" // spain
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets (has cost implications)"
  type        = bool
  default     = false
}

variable "enable_alb" {
  description = "Enable ALB service for better web protection"
  type        = bool
  default     = false
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS on ALB (if ALB required)"
  type        = string
  default     = null
}

variable "jenkins_controller_host_headers" {
  description = "Host headers for Jenkins Controller routing (e.g., ['jenkins.example.com'])"
  type        = list(string)
  default     = []
}

variable "sonarqube_host_headers" {
  description = "Host headers for SonarQube routing (e.g., ['sonarqube.example.com'])"
  type        = list(string)
  default     = []
}

variable "artifactory_host_headers" {
  description = "Host headers for Artifactory routing (e.g., ['artifactory.example.com'])"
  type        = list(string)
  default     = []
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

variable "allowed_https_source_github_hooks_ips4" {
  description = "List of GitHub Hooks IPs v4 allowed for HTTPS access"
  type        = list(string)
}

variable "allowed_https_source_github_hooks_ips6" {
  description = "List of GitHub Hooks IPs v6 allowed for HTTPS access"
  type        = list(string)
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "/path/to/sshkey.pub"
}

variable "secret_prefix" {
  description = "Prefix for all secret names (e.g., 'devsecops' creates 'devsecops/github-pat')"
  type        = string
  default     = "devsecops"
}

variable "secrets" {
  description = "Secrets to store"
  type        = map(string)
  sensitive   = true
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
