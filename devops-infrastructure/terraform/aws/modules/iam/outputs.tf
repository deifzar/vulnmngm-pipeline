# =============================================================================
# Jenkins Controller
# =============================================================================
output "jenkins_controller_role_arn" {
  description = "ARN of the Jenkins Controller IAM role"
  value       = aws_iam_role.jenkins_controller.arn
}

output "jenkins_controller_role_name" {
  description = "Name of the Jenkins Controller IAM role"
  value       = aws_iam_role.jenkins_controller.name
}

output "jenkins_controller_instance_profile_arn" {
  description = "ARN of the Jenkins Controller instance profile"
  value       = aws_iam_instance_profile.jenkins_controller.arn
}

output "jenkins_controller_instance_profile_name" {
  description = "Name of the Jenkins Controller instance profile"
  value       = aws_iam_instance_profile.jenkins_controller.name
}

# =============================================================================
# Jenkins Agent
# =============================================================================
output "jenkins_agent_role_arn" {
  description = "ARN of the Jenkins Agent IAM role"
  value       = aws_iam_role.jenkins_agent.arn
}

output "jenkins_agent_role_name" {
  description = "Name of the Jenkins Agent IAM role"
  value       = aws_iam_role.jenkins_agent.name
}

output "jenkins_agent_instance_profile_arn" {
  description = "ARN of the Jenkins Agent instance profile"
  value       = aws_iam_instance_profile.jenkins_agent.arn
}

output "jenkins_agent_instance_profile_name" {
  description = "Name of the Jenkins Agent instance profile"
  value       = aws_iam_instance_profile.jenkins_agent.name
}

# =============================================================================
# SonarQube
# =============================================================================
output "sonarqube_role_arn" {
  description = "ARN of the SonarQube IAM role"
  value       = aws_iam_role.sonarqube.arn
}

output "sonarqube_role_name" {
  description = "Name of the SonarQube IAM role"
  value       = aws_iam_role.sonarqube.name
}

output "sonarqube_instance_profile_arn" {
  description = "ARN of the SonarQube instance profile"
  value       = aws_iam_instance_profile.sonarqube.arn
}

output "sonarqube_instance_profile_name" {
  description = "Name of the SonarQube instance profile"
  value       = aws_iam_instance_profile.sonarqube.name
}

# =============================================================================
# Artifactory
# =============================================================================
output "artifactory_role_arn" {
  description = "ARN of the Artifactory IAM role"
  value       = aws_iam_role.artifactory.arn
}

output "artifactory_role_name" {
  description = "Name of the Artifactory IAM role"
  value       = aws_iam_role.artifactory.name
}

output "artifactory_instance_profile_arn" {
  description = "ARN of the Artifactory instance profile"
  value       = aws_iam_instance_profile.artifactory.arn
}

output "artifactory_instance_profile_name" {
  description = "Name of the Artifactory instance profile"
  value       = aws_iam_instance_profile.artifactory.name
}