terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.location
  profile = var.aws_profile

  default_tags {
    tags = var.tags
  }
}

# Data source for current AWS caller identity
data "aws_caller_identity" "current" {}

# Data source for available AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# =============================================================================
# Networking Module
# =============================================================================
module "networking" {
  source = "../../modules/networking"

  project_name       = "devsecops-${var.environment}"
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24"]
  database_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24"]

  enable_nat_gateway = var.enable_nat_gateway

  tags = var.tags
}

# =============================================================================
# Security Module For ALB
# =============================================================================
module "security_alb" {
  count  = var.enable_alb ? 1 : 0
  source = "../../modules/security"

  name        = "scg-alb"
  description = "Security Group rules for AWS ALB"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      "HTTPForLetsEncrypt" = {
        description = "HTTP for Lets Encrypt and redirect"
        to_port     = 80
        from_port   = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    # HTTPS from specific IP
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        description = "HTTPS from authorized IP ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    # HTTPS from specific GitHub IPs
    {
      for idx, ip in var.allowed_https_source_github_hooks_ips4 : "AllowHTTPS-GitHub-IPv4-${idx}" => {
        description = "HTTPS from authorized GitHub IPs v4 ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    {
      for idx, ip in var.allowed_https_source_github_hooks_ips6 : "AllowHTTPS-GitHub-IPv6-${idx}" => {
        description = "HTTPS from authorized GitHub IPs v6 ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv6   = ip
      }
    }
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws alb"
  })

  depends_on = [module.networking]
}

# ============================================================================= 
# Security Groups for Jenkins Controller
# =============================================================================

module "security_jenkins_controller" {
  source = "../../modules/security"

  name        = "scg-jenkins-controller"
  description = "Security Group rules for Jenins Controller"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        description = "SSH from authorized IP ${idx}"
        to_port     = 22
        from_port   = 22
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    {
      "HTTPForLetsEncrypt" = {
        description = "HTTP for Lets Encrypt and redirect"
        to_port     = 80
        from_port   = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    # HTTPS from specific IP (if not ALB)
    var.enable_alb ? {} :
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        description = "HTTPS from authorized IP ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    # HTTPS from specific GitHub IPs (if not ALB)
    var.enable_alb ? {} :
    {
      for idx, ip in var.allowed_https_source_github_hooks_ips4 : "AllowHTTPS-GitHub-IP4v${idx}" => {
        description = "HTTPS from authorized GitHub IPs IP4v ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    var.enable_alb ? {} :
    {
      for idx, ip in var.allowed_https_source_github_hooks_ips6 : "AllowHTTPS-GitHub-IP6v${idx}" => {
        description = "HTTPS from authorized GitHub IPs IP6v ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv6   = ip
      }
    },
    # HTTP from ALB (if ALB)
    var.enable_alb ? {
      "AllowALBInbound" : {
        description                  = "HTTPS from AWS ALB"
        to_port                      = 8080
        from_port                    = 8080
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_alb[0].security_group_id
      }
    } : {},
    # JNLP from private subnets
    {
      for idx, cidr in module.networking.private_subnet_cidrs : "AllowJNLPInbound-${idx}" =>
      {
        description = "JNLP from private subnet - ${cidr}"
        to_port     = 50000
        from_port   = 50000
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
      }
    },
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws ec2"
  })

  depends_on = [module.networking, module.security_alb]
}

# ============================================================================= 
# Security Groups for Jenkins Agent
# =============================================================================

module "security_jenkins_agent" {
  source = "../../modules/security"

  name        = "scg-jenkins-agent"
  description = "Security Group rules for Jenins Agent"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        description = "SSH from authorized IP ${idx}"
        to_port     = 22
        from_port   = 22
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws ec2"
  })

  depends_on = [module.networking]
}

# ============================================================================= 
# Security Groups for SonarQube
# =============================================================================

module "security_sonarqube" {
  source = "../../modules/security"

  name        = "scg-sonarqube"
  description = "Security Group rules for SonarQube"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        description = "SSH from authorized IP ${idx}"
        to_port     = 22
        from_port   = 22
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    {
      "HTTPForLetsEncrypt" = {
        description = "HTTP for Lets Encrypt and redirect"
        to_port     = 80
        from_port   = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    # HTTPS from specific IP (if not ALB)
    var.enable_alb ? {} :
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        description = "HTTPS from authorized IP ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    # HTTP from ALB (if ALB)
    var.enable_alb ? {
      "AllowALBInbound" : {
        description                  = "HTTPS from AWS ALB"
        to_port                      = 9000
        from_port                    = 9000
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_alb[0].security_group_id
      }
    } : {},
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws ec2"
  })

  depends_on = [module.networking, module.security_alb]
}

# ============================================================================= 
# Security Groups for JFrog Artifactory
# =============================================================================

module "security_artifactory" {
  source = "../../modules/security"

  name        = "scg-artifactory"
  description = "Security Group rules for Artifactory"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        description = "SSH from authorized IP ${idx}"
        to_port     = 22
        from_port   = 22
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    {
      "HTTPForLetsEncrypt" = {
        description = "HTTP for Lets Encrypt and redirect"
        to_port     = 80
        from_port   = 80
        ip_protocol = "tcp"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    # HTTPS from specific IP (if not ALB)
    var.enable_alb ? {} :
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        description = "HTTPS from authorized IP ${idx}"
        to_port     = 443
        from_port   = 443
        ip_protocol = "tcp"
        cidr_ipv4   = ip
      }
    },
    # HTTP from ALB (if ALB)
    var.enable_alb ? {
      "AllowALBInbound" : {
        description                  = "HTTPS from AWS ALB"
        to_port                      = 8082
        from_port                    = 8082
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_alb[0].security_group_id
      }
    } : {},
    # HTTP from Private subnets
    {
      for idx, cidr in module.networking.private_subnet_cidrs : "AllowHTTPPrivateSubnetsInbound-${idx}" =>
      {
        description = "HTTP from private subnet - ${cidr}"
        to_port     = 8081
        from_port   = 8081
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
      }
    },
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws ec2"
  })

  depends_on = [module.networking, module.security_alb]
}

# ============================================================================= 
# Security Groups for RDS
# =============================================================================

module "security_rds" {
  source = "../../modules/security"

  name        = "scg-rds"
  description = "Security Group rules for RDS"
  vpc_id      = module.networking.vpc_id

  ingress_rules = merge(
    {
      "PostgreSQLJenkinsConstroller" = {
        description                  = "PostgreSQL from Jenkins Controller"
        to_port                      = 5432
        from_port                    = 5432
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_jenkins_controller.security_group_id
      }
    },
    {
      "PostgreSQLSonarQube" = {
        description                  = "PostgreSQL from SonarQube"
        to_port                      = 5432
        from_port                    = 5432
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_sonarqube.security_group_id
      }
    },
    {
      "PostgreArtifactory" = {
        description                  = "PostgreSQL from Artifactory"
        to_port                      = 5432
        from_port                    = 5432
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.security_artifactory.security_group_id
      }
    },
  )

  egress_rules = {
    "AllEgress" = {
      description = "Allow all outbout"
      to_port     = 0
      from_port   = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = merge(var.tags, {
    service = "aws ec2"
  })

  depends_on = [module.security_jenkins_controller, module.security_sonarqube, module.security_artifactory]
}

# =============================================================================
# KMS Module (for EBS encryption)
# =============================================================================
module "kms" {
  source = "../../modules/kms"

  project_name            = "devsecops-${var.environment}"
  description             = "DevSecOps ${var.environment} infrastructure encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30

  tags = merge(var.tags, {
    service = "aws kms"
  })
}

# =============================================================================
# IAM Module (roles and instance profiles)
# =============================================================================
module "iam" {
  source = "../../modules/iam"

  project_name = "devsecops-${var.environment}"
  kms_key_arn  = module.kms.key_arn // EBS encryption key

  secrets_prefix = var.secret_prefix

  tags = var.tags

  depends_on = [module.kms]
}

# =============================================================================
# Secrets Manager Module
# =============================================================================
module "secretsmanager" {
  source = "../../modules/secretsmanager"

  secret_prefix = var.secret_prefix

  secrets = var.secrets

  tags = var.tags
}

# =============================================================================
# SSH Key Pair
# =============================================================================
resource "aws_key_pair" "devsecops" {
  key_name   = "devsecops-${var.environment}-key"
  public_key = file(var.ssh_public_key_path)

  tags = merge(var.tags, {
    Name = "devsecops-${var.environment}-key"
  })
}

# =============================================================================
# EC2 Instances
# =============================================================================

locals {
  # Map of common default users for various AMIs
  ami_users = {
    "ubuntu" = "ubuntu"
    "amazon" = "ec2-user"
    "debian" = "admin"
    "rhel"   = "ec2-user"
  }
}

# Jenkins Controller
module "ec2_jenkins_controller" {
  source = "../../modules/compute"

  instance_name        = "jenkins-controller-${var.environment}"
  instance_type        = "t3.medium"
  subnet_id            = var.enable_alb ? module.networking.private_subnet_ids[0] : module.networking.public_subnet_ids[0]
  security_group_ids   = [module.security_jenkins_controller.security_group_id]
  iam_instance_profile = module.iam.jenkins_controller_instance_profile_name
  key_name             = aws_key_pair.devsecops.key_name
  root_volume_size     = 100
  kms_key_arn          = module.kms.key_arn

  create_elastic_ip = !var.enable_alb

  tags = merge(var.tags, {
    Service = "Jenkins Controller"
    Role    = "CI/CD"
  })
}

# # Jenkins Agent
# module "ec2_jenkins_agent" {
#   source = "../../modules/compute"

#   instance_name        = "jenkins-agent-${var.environment}"
#   instance_type        = "t3.medium"
#   subnet_id            = module.networking.private_subnet_ids[0]
#   security_group_ids   = [module.security_jenkins_agent.security_group_id]
#   iam_instance_profile = module.iam.jenkins_agent_instance_profile_name
#   key_name             = aws_key_pair.devsecops.key_name
#   root_volume_size     = 100
#   kms_key_arn          = module.kms.key_arn

#   create_elastic_ip = !var.enable_alb

#   tags = merge(var.tags, {
#     Service = "Jenkins Agent"
#     Role    = "CI/CD"
#   })
# }

# SonarQube
module "ec2_sonarqube" {
  source = "../../modules/compute"

  instance_name        = "sonarqube-${var.environment}"
  instance_type        = "t3.medium"
  subnet_id            = var.enable_alb ? module.networking.private_subnet_ids[0] : module.networking.public_subnet_ids[0]
  security_group_ids   = [module.security_sonarqube.security_group_id]
  iam_instance_profile = module.iam.sonarqube_instance_profile_name
  key_name             = aws_key_pair.devsecops.key_name
  root_volume_size     = 100
  kms_key_arn          = module.kms.key_arn

  create_elastic_ip = !var.enable_alb

  tags = merge(var.tags, {
    Service = "SonarQube"
    Role    = "SAST"
  })
}

# Artifactory
# module "ec2_artifactory" {
#   source = "../../modules/compute"

#   instance_name        = "artifactory-${var.environment}"
#   instance_type        = "t3.medium"
#   subnet_id            = var.enable_alb ? module.networking.private_subnet_ids[0] : module.networking.public_subnet_ids[0]
#   security_group_ids   = [module.security_artifactory.security_group_id]
#   iam_instance_profile = module.iam.artifactory_instance_profile_name
#   key_name             = aws_key_pair.devsecops.key_name
#   root_volume_size     = 100
#   kms_key_arn          = module.kms.key_arn

#   create_elastic_ip = !var.enable_alb

#   tags = merge(var.tags, {
#     Service = "Artifactory"
#     Role    = "Artifact Repository"
#   })
# }

# =============================================================================
# RDS PostgreSQL Instances
# =============================================================================

# PostgreSQL for SonarQube
module "rds_sonarqube" {
  source = "../../modules/rds"

  instance_name         = "rds-sonarqube-${var.environment}"
  database_name         = "sonarqube"
  admin_username        = "sqadmin"
  admin_password        = var.secrets.postgresql-sonarqube-admin-password
  instance_class        = "db.t3.medium"
  allocated_storage     = 20
  max_allocated_storage = 100

  engine_version = "14.15"

  db_subnet_group_name = module.networking.db_subnet_group_name
  security_group_ids   = [module.security_rds.security_group_id]
  kms_key_arn          = module.kms.key_arn

  # Backup configuration
  backup_retention_days = 7
  backup_window         = "02:30-03:30"
  maintenance_window    = "Mon:04:00-Mon:05:00" # OS Patching, DB minor upgrades, Queued modifications, Hardware maintance
  skip_final_snapshot   = var.environment != "production"
  deletion_protection   = var.environment == "production"

  # Monitoring
  enable_performance_insights   = false
  cloudwatch_log_exports        = ["postgresql", "upgrade"]
  cloudwatch_log_retention_days = 30

  tags = merge(var.tags, {
    Service = "PostgreSQL-SonarQube"
    Role    = "SAST Data"
  })

  depends_on = [module.networking, module.security_rds]
}

# PostgreSQL for Artifactory
module "rds_artifactory" {
  source = "../../modules/rds"

  instance_name         = "rds-artifactory-${var.environment}"
  database_name         = "artifactory"
  admin_username        = "sqadmin"
  admin_password        = var.secrets.postgresql-artifactory-admin-password
  instance_class        = "db.t3.medium"
  allocated_storage     = 20
  max_allocated_storage = 100

  engine_version = "14.15"

  db_subnet_group_name = module.networking.db_subnet_group_name
  security_group_ids   = [module.security_rds.security_group_id]
  kms_key_arn          = module.kms.key_arn

  # Backup configuration
  backup_retention_days = 7
  backup_window         = "02:30-03:30"
  maintenance_window    = "Tue:04:00-Tue:05:00"
  skip_final_snapshot   = var.environment != "production"
  deletion_protection   = var.environment == "production"

  # Monitoring
  enable_performance_insights   = false
  cloudwatch_log_exports        = ["postgresql", "upgrade"]
  cloudwatch_log_retention_days = 30

  tags = merge(var.tags, {
    Service = "PostgreSQL-Artifactory"
    Role    = "Artifact Repository Data"
  })

  depends_on = [module.networking, module.security_rds]
}

# =============================================================================
# Application Load Balancer
# =============================================================================
module "alb" {
  count  = var.enable_alb ? 1 : 0
  source = "../../modules/alb"

  name               = "alb-devsecops-${var.environment}"
  internal           = false
  vpc_id             = module.networking.vpc_id
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.security_alb[0].security_group_id]

  enable_deletion_protection = var.environment == "production"
  idle_timeout               = 60

  # Access logs (disabled by default - enable if you have an S3 bucket)
  enable_access_logs = false
  access_logs_bucket = ""
  access_logs_prefix = "alb-logs"

  # Target groups for each service
  target_groups = {
    jenkins = {
      name                = "tg-jenkins-${var.environment}"
      port                = 8080
      protocol            = "HTTP"
      target_type         = "instance"
      stickiness_enabled  = true
      stickiness_duration = 3600
      health_check = {
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        path                = "/login"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200-399"
      }
    }
    sonarqube = {
      name                = "tg-sonarqube-${var.environment}"
      port                = 9000
      protocol            = "HTTP"
      target_type         = "instance"
      stickiness_enabled  = true
      stickiness_duration = 3600
      health_check = {
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 5
        interval            = 30
        path                = "/api/system/status"
        port                = "traffic-port"
        protocol            = "HTTP"
        matcher             = "200"
      }
    }
    # artifactory = {
    #   name                = "tg-artifactory-${var.environment}"
    #   port                = 8082
    #   protocol            = "HTTP"
    #   target_type         = "instance"
    #   stickiness_enabled  = true
    #   stickiness_duration = 3600
    #   health_check = {
    #     healthy_threshold   = 2
    #     unhealthy_threshold = 3
    #     timeout             = 5
    #     interval            = 30
    #     path                = "/artifactory/api/system/ping"
    #     port                = "traffic-port"
    #     protocol            = "HTTP"
    #     matcher             = "200"
    #   }
    # }
  }

  # Target group attachments
  target_group_attachments = {
    jenkins = {
      target_group_key = "jenkins"
      target_id        = module.ec2_jenkins_controller.instance_id
      port             = 8080
    }
    sonarqube = {
      target_group_key = "sonarqube"
      target_id        = module.ec2_sonarqube.instance_id
      port             = 9000
    }
    # artifactory = {
    #   target_group_key = "artifactory"
    #   target_id        = module.ec2_artifactory.instance_id
    #   port             = 8082
    # }
  }

  # Listeners
  create_http_listener  = true
  create_https_listener = var.acm_certificate_arn != null

  certificate_arn          = var.acm_certificate_arn
  ssl_policy               = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_target_group_key = "jenkins"

  # Host-based routing rules
  listener_rules = var.acm_certificate_arn != null ? {
    jenkins = {
      priority         = 200
      target_group_key = "jenkins-controller"
      host_headers     = var.jenkins_controller_host_headers
      path_patterns    = null
    }
    sonarqube = {
      priority         = 300
      target_group_key = "sonarqube"
      host_headers     = var.sonarqube_host_headers
      path_patterns    = null
    }
    artifactory = {
      priority         = 400
      target_group_key = "artifactory"
      host_headers     = var.artifactory_host_headers
      path_patterns    = null
    }
  } : {}

  tags = merge(var.tags, {
    Service = "Application Load Balancer"
    Role    = "Load Balancing"
  })

  depends_on = [
    module.security_alb,
    module.ec2_jenkins_controller,
    module.ec2_sonarqube,
    # module.ec2_artifactory
  ]
}
