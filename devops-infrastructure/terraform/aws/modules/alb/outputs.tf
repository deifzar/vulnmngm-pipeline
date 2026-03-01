# =============================================================================
# Load Balancer Outputs
# =============================================================================
output "alb_id" {
  description = "The ID of the Application Load Balancer"
  value       = aws_lb.this.id
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB (for Route53 alias records)"
  value       = aws_lb.this.zone_id
}

output "alb_arn_suffix" {
  description = "The ARN suffix for use with CloudWatch Metrics"
  value       = aws_lb.this.arn_suffix
}

# =============================================================================
# Target Group Outputs
# =============================================================================
output "target_group_arns" {
  description = "Map of target group ARNs"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn }
}

output "target_group_names" {
  description = "Map of target group names"
  value       = { for k, v in aws_lb_target_group.this : k => v.name }
}

output "target_group_arn_suffixes" {
  description = "Map of target group ARN suffixes (for CloudWatch Metrics)"
  value       = { for k, v in aws_lb_target_group.this : k => v.arn_suffix }
}

# =============================================================================
# Listener Outputs
# =============================================================================
output "http_listener_arn" {
  description = "The ARN of the HTTP listener"
  value       = try(aws_lb_listener.http[0].arn, null)
}

output "https_listener_arn" {
  description = "The ARN of the HTTPS listener"
  value       = try(aws_lb_listener.https[0].arn, null)
}