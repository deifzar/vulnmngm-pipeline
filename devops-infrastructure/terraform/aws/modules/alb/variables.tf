# =============================================================================
# Load Balancer Configuration
# =============================================================================
variable "name" {
  description = "Name of the Application Load Balancer"
  type        = string
}

variable "internal" {
  description = "Whether the load balancer is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "VPC ID where the ALB resources will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ALB (should be public subnets for internet-facing)"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for the ALB"
  type        = list(string)
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = false
}

variable "idle_timeout" {
  description = "Idle timeout in seconds"
  type        = number
  default     = 60
}

# =============================================================================
# Access Logs Configuration
# =============================================================================
variable "enable_access_logs" {
  description = "Enable access logs for the ALB"
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for access logs"
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "S3 key prefix for access logs"
  type        = string
  default     = "alb-logs"
}

# =============================================================================
# Target Groups Configuration
# =============================================================================
variable "target_groups" {
  description = "Map of target group configurations"
  type = map(object({
    name                = string
    port                = number
    protocol            = string
    target_type         = string
    stickiness_enabled  = bool
    stickiness_duration = number
    health_check = object({
      healthy_threshold   = number
      unhealthy_threshold = number
      timeout             = number
      interval            = number
      path                = string
      port                = string
      protocol            = string
      matcher             = string
    })
  }))
  default = {}
}

variable "target_group_attachments" {
  description = "Map of target group attachments (instance to target group mappings)"
  type = map(object({
    target_group_key = string
    target_id        = string
    port             = number
  }))
  default = {}
}

# =============================================================================
# HTTP Listener Configuration
# =============================================================================
variable "create_http_listener" {
  description = "Create HTTP listener (redirects to HTTPS)"
  type        = bool
  default     = true
}

# =============================================================================
# HTTPS Listener Configuration
# =============================================================================
variable "create_https_listener" {
  description = "Create HTTPS listener"
  type        = bool
  default     = true
}

variable "certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

variable "additional_certificates" {
  description = "Map of additional ACM certificate ARNs for the HTTPS listener"
  type        = map(string)
  default     = {}
}

variable "ssl_policy" {
  description = "SSL policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "default_target_group_key" {
  description = "Key of the default target group for HTTPS listener"
  type        = string
  default     = null
}

# =============================================================================
# Listener Rules Configuration
# =============================================================================
variable "listener_rules" {
  description = "Map of listener rules for path/host-based routing"
  type = map(object({
    priority         = number
    target_group_key = string
    host_headers     = optional(list(string))
    path_patterns    = optional(list(string))
  }))
  default = {}
}

# =============================================================================
# Tags
# =============================================================================
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
