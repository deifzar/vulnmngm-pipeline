# =============================================================================
# Networking Outputs
# =============================================================================
output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = module.networking.private_subnet_ids
}

output "database_subnet_ids" {
  description = "List of database subnet IDs"
  value       = module.networking.database_subnet_ids
}

output "nat_gateway_public_ip" {
  description = "The public IP of the NAT Gateway"
  value       = module.networking.nat_gateway_public_ip
}

output "db_subnet_group_name" {
  description = "The name of the DB subnet group for RDS"
  value       = module.networking.db_subnet_group_name
}

# =============================================================================
# Security Group Outputs
# =============================================================================
output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = var.enable_alb ? module.security_alb[0].security_group_id : null
}

output "jenkins_controller_security_group_id" {
  description = "Security group ID for Jenkins Controller"
  value       = module.security_jenkins_controller.security_group_id
}

output "jenkins_agent_security_group_id" {
  description = "Security group ID for Jenkins Agents"
  value       = module.security_jenkins_agent.security_group_id
}

output "sonarqube_security_group_id" {
  description = "Security group ID for SonarQube"
  value       = module.security_sonarqube.security_group_id
}

output "artifactory_security_group_id" {
  description = "Security group ID for Artifactory"
  value       = module.security_artifactory.security_group_id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS PostgreSQL"
  value       = module.security_rds.security_group_id
}

# =============================================================================
# KMS Outputs
# =============================================================================
output "kms_key_id" {
  description = "The ID of the KMS key for EBS encryption"
  value       = module.kms.key_id
}

output "kms_key_arn" {
  description = "The ARN of the KMS key for EBS encryption"
  value       = module.kms.key_arn
}

output "kms_alias_name" {
  description = "The alias name of the KMS key"
  value       = module.kms.alias_name
}

# =============================================================================
# IAM Outputs
# =============================================================================
output "jenkins_controller_instance_profile_name" {
  description = "Instance profile name for Jenkins Controller"
  value       = module.iam.jenkins_controller_instance_profile_name
}

output "jenkins_agent_instance_profile_name" {
  description = "Instance profile name for Jenkins Agent"
  value       = module.iam.jenkins_agent_instance_profile_name
}

output "sonarqube_instance_profile_name" {
  description = "Instance profile name for SonarQube"
  value       = module.iam.sonarqube_instance_profile_name
}

output "artifactory_instance_profile_name" {
  description = "Instance profile name for Artifactory"
  value       = module.iam.artifactory_instance_profile_name
}

# =============================================================================
# EC2 Instance Outputs
# =============================================================================
output "jenkins_controller_instance_id" {
  description = "Instance ID of Jenkins Controller"
  value       = module.ec2_jenkins_controller.instance_id
}

output "jenkins_controller_private_ip" {
  description = "Private IP of Jenkins Controller"
  value       = module.ec2_jenkins_controller.private_ip
}

output "jenkins_controller_public_ip" {
  description = "Public/Elastic IP of Jenkins Controller (if ALB disabled)"
  value       = module.ec2_jenkins_controller.elastic_ip
}

# output "jenkins_agent_instance_id" {
#   description = "Instance ID of Jenkins Agent"
#   value       = module.ec2_jenkins_agent.instance_id
# }

# output "jenkins_agent_private_ip" {
#   description = "Private IP of Jenkins Agent"
#   value       = module.ec2_jenkins_agent.private_ip
# }

output "sonarqube_instance_id" {
  description = "Instance ID of SonarQube"
  value       = module.ec2_sonarqube.instance_id
}

output "sonarqube_private_ip" {
  description = "Private IP of SonarQube"
  value       = module.ec2_sonarqube.private_ip
}

# output "artifactory_instance_id" {
#   description = "Instance ID of Artifactory"
#   value       = module.ec2_artifactory.instance_id
# }

# output "artifactory_private_ip" {
#   description = "Private IP of Artifactory"
#   value       = module.ec2_artifactory.private_ip
# }

# =============================================================================
# RDS Outputs
# =============================================================================
output "rds_sonarqube_endpoint" {
  description = "RDS endpoint for SonarQube PostgreSQL"
  value       = module.rds_sonarqube.endpoint
}

output "rds_sonarqube_address" {
  description = "RDS hostname for SonarQube PostgreSQL"
  value       = module.rds_sonarqube.address
}

output "rds_artifactory_endpoint" {
  description = "RDS endpoint for Artifactory PostgreSQL"
  value       = module.rds_artifactory.endpoint
}

output "rds_artifactory_address" {
  description = "RDS hostname for Artifactory PostgreSQL"
  value       = module.rds_artifactory.address
}

# =============================================================================
# ALB Outputs
# =============================================================================
output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = var.enable_alb ? module.alb[0].alb_dns_name : null
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the ALB (for Route53 alias records)"
  value       = var.enable_alb ? module.alb[0].alb_zone_id : null
}

output "alb_arn" {
  description = "The ARN of the Application Load Balancer"
  value       = var.enable_alb ? module.alb[0].alb_arn : null
}

output "alb_target_group_arns" {
  description = "Map of target group ARNs"
  value       = var.enable_alb ? module.alb[0].target_group_arns : null
}

# =============================================================================
# Ansible Outputs
# =============================================================================
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    secrets_arn = {
      arns = module.secretsmanager.secret_arns_map
    }
    jenkins_controller = {
      ansible_host = module.ec2_jenkins_controller.elastic_ip
      instance_id  = module.ec2_jenkins_controller.instance_id
      ansible_user = local.ami_users.ubuntu
      private_ip   = module.ec2_jenkins_controller.private_ip
    }
    # jenkins_agent = {
    #   ansible_host = module.ec2_jenkins_agent.elastic_ip
    #   instance_id  = module.ec2_jenkins_agent.instance_id
    #   ansible_user = local.ami_users.ubuntu
    #   private_ip   = module.ec2_jenkins_agent.private_ip
    # }
    sonarqube = {
      ansible_host      = module.ec2_sonarqube.elastic_ip
      instance_id       = module.ec2_sonarqube.instance_id
      ansible_user      = local.ami_users.ubuntu
      private_ip        = module.ec2_sonarqube.private_ip
      sonarqube_db_host = module.rds_sonarqube.address
    }
    # artifactory = {
    #   ansible_host = module.ec2_artifactory.elastic_ip
    #   instance_id  = module.ec2_artifactory.instance_id
    #   ansible_user = local.ami_users.ubuntu
    #   private_ip   = module.ec2_artifactory.private_ip
    #   artifactory_db_host = module.rds_artifactory.address
    # }
  }
}
