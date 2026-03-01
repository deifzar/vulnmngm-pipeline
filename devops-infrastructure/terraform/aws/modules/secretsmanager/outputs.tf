# =============================================================================
# Secret Prefix (for IAM policy wildcards)
# =============================================================================
output "secret_prefix" {
  description = "The prefix used for all secrets (for IAM policy wildcards)"
  value       = var.secret_prefix
}

output "secret_arns_map" {
  description = "Map of secret names to their ARNs"
  value       = { for k, v in aws_secretsmanager_secret.devsecops-ssm : k => v.arn }
}

output "secret_arns_list" {
  description = "List of all secret ARNs"
  value       = [for s in aws_secretsmanager_secret.devsecops-ssm : s.arn]
}
