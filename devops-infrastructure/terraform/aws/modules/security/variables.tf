variable "name" {
  description = "Security Group name"
  type        = string
}

variable "description" {
  description = "Security Group description"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where security groups will be created"
  type        = string
}

variable "ingress_rules" {
  description = "Map of Ingress security rules to create"
  type = map(object({
    security_group_id            = optional(string)
    description                  = string
    to_port                      = number
    from_port                    = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
}

variable "egress_rules" {
  description = "Map of Egress security rules to create"
  type = map(object({
    security_group_id            = optional(string)
    description                  = string
    to_port                      = number
    from_port                    = number
    ip_protocol                  = string
    cidr_ipv4                    = optional(string)
    cidr_ipv6                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
