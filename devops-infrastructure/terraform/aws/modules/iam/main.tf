# Data source for current AWS account
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# Common: EC2 Assume Role Policy
# =============================================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

# =============================================================================
# JENKINS CONTROLLER
# =============================================================================
resource "aws_iam_role" "jenkins_controller" {
  name               = "${var.project_name}-jenkins-controller-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-controller-role"
  })
}

# Managed policies for Jenkins Controller
resource "aws_iam_role_policy_attachment" "jenkins_controller_ssm" {
  role       = aws_iam_role.jenkins_controller.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jenkins_controller_cloudwatch" {
  role       = aws_iam_role.jenkins_controller.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Inline policy: Secrets Manager access for Jenkins secrets
resource "aws_iam_role_policy" "jenkins_controller_secrets" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.jenkins_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}/*"
      }
    ]
  })
}

# Inline policy: KMS decrypt for secrets
# When is the KMS policy needed for Secrets Manager?
# 1. Using a Customer Managed Key (CMK) - You need explicit kms:Decrypt permission
# 2. Using the default AWS-managed key (aws/secretsmanager) - KMS permission is handled automatically, not needed

# WE ARE USING AWS Managed Key therefore, we comment the following lines
# This is not related to the EBS disk encryption policy is granted by the EC2 role !!
# resource "aws_iam_role_policy" "jenkins_controller_kms" {
#   name = "KMSDecryptAccess"
#   role = aws_iam_role.jenkins_controller.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "kms:Decrypt",
#           "kms:DescribeKey"
#         ]
#         Resource = var.kms_key_arn
#       }
#     ]
#   })
# }

# Inline policy: ECR access for Docker operations
resource "aws_iam_role_policy" "jenkins_controller_ecr" {
  name = "ECRAccess"
  role = aws_iam_role.jenkins_controller.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# Instance Profile for Jenkins Controller
resource "aws_iam_instance_profile" "jenkins_controller" {
  name = "${var.project_name}-jenkins-controller-profile"
  role = aws_iam_role.jenkins_controller.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-controller-profile"
  })
}

# =============================================================================
# JENKINS AGENT
# =============================================================================
resource "aws_iam_role" "jenkins_agent" {
  name               = "${var.project_name}-jenkins-agent-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-agent-role"
  })
}

# Managed policies for Jenkins Agent
resource "aws_iam_role_policy_attachment" "jenkins_agent_ssm" {
  role       = aws_iam_role.jenkins_agent.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "jenkins_agent_cloudwatch" {
  role       = aws_iam_role.jenkins_agent.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Inline policy: ECR access for Docker operations
resource "aws_iam_role_policy" "jenkins_agent_ecr" {
  name = "ECRAccess"
  role = aws_iam_role.jenkins_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/*"
      }
    ]
  })
}

# Inline policy: Secrets Manager read-only for pipeline secrets
resource "aws_iam_role_policy" "jenkins_agent_secrets" {
  name = "SecretsManagerReadOnly"
  role = aws_iam_role.jenkins_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}/*"
      }
    ]
  })
}

# Instance Profile for Jenkins Agent
resource "aws_iam_instance_profile" "jenkins_agent" {
  name = "${var.project_name}-jenkins-agent-profile"
  role = aws_iam_role.jenkins_agent.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-jenkins-agent-profile"
  })
}

# =============================================================================
# SONARQUBE
# =============================================================================
resource "aws_iam_role" "sonarqube" {
  name               = "${var.project_name}-sonarqube-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-sonarqube-role"
  })
}

# Managed policies for SonarQube
resource "aws_iam_role_policy_attachment" "sonarqube_ssm" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "sonarqube_cloudwatch" {
  role       = aws_iam_role.sonarqube.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Inline policy: Secrets Manager access for SonarQube secrets (PostgreSQL password)
resource "aws_iam_role_policy" "sonarqube_secrets" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.sonarqube.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}/*"
      }
    ]
  })
}

# Instance Profile for SonarQube
resource "aws_iam_instance_profile" "sonarqube" {
  name = "${var.project_name}-sonarqube-profile"
  role = aws_iam_role.sonarqube.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-sonarqube-profile"
  })
}

# =============================================================================
# ARTIFACTORY
# =============================================================================
resource "aws_iam_role" "artifactory" {
  name               = "${var.project_name}-artifactory-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-artifactory-role"
  })
}

# Managed policies for Artifactory Controller
resource "aws_iam_role_policy_attachment" "artifactory_controller_ssm" {
  role       = aws_iam_role.artifactory.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "artifactory_cloudwatch" {
  role       = aws_iam_role.artifactory.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Inline policy: Secrets Manager access for Artifactory secrets
resource "aws_iam_role_policy" "artifactory_secrets" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.artifactory.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_prefix}/*"
      }
    ]
  })
}

# Instance Profile for Artifactory
resource "aws_iam_instance_profile" "artifactory" {
  name = "${var.project_name}-artifactory-profile"
  role = aws_iam_role.artifactory.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-artifactory-profile"
  })
}
