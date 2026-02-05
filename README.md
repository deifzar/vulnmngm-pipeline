# DevSecOps Infrastructure Pipeline

A **cloud-agnostic** Infrastructure as Code (IaC) project demonstrating the deployment of a complete DevSecOps toolchain using Terraform and Ansible. Currently implemented on Azure with AWS support planned.

## Overview

This project showcases proficiency in building production-ready DevOps infrastructure through:

- **Infrastructure Provisioning**: Terraform modules with cloud-agnostic design patterns
- **Configuration Management**: Ansible roles for application deployment and hardening
- **Security-First Design**: Network segmentation, encryption, and security baselines
- **Multi-Cloud Strategy**: Designed to be portable across Azure and AWS

## CPTM8 Project Integration

This DevSecOps infrastructure is designed to support the [CPTM8 project](https://github.com/deifzar), implementing a **shift-left security** approach that integrates security practices early in the development lifecycle:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Shift-Left Security Pipeline                         │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────────┤
│    Code     │    Build    │    Test     │   Deploy    │      Monitor        │
├─────────────┼─────────────┼─────────────┼─────────────┼─────────────────────┤
│ SonarQube   │ Trivy       │ DAST        │ Harbor      │ Prometheus          │
│ (SAST)      │ (Container  │ (Dynamic    │ (Secure     │ Grafana             │
│             │  Scanning)  │  Analysis)  │  Registry)  │                     │
│ Pre-commit  │ Dependency  │ Pen Testing │ Signed      │ Security            │
│ Hooks       │ Scanning    │             │ Images      │ Dashboards          │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────────────┘
```

**Key Integration Points:**

- **Early Vulnerability Detection**: SonarQube scans CPTM8 code on every commit
- **Container Security**: Trivy and Harbor ensure secure container images
- **Automated CI/CD**: Jenkins pipelines with built-in security gates
- **Artifact Management**: Artifactory for secure dependency management

## Architecture

```
                                    +------------------+
                                    |   Azure Cloud    |
                                    +--------+---------+
                                             |
                    +------------------------+------------------------+
                    |                        |                        |
           +--------v--------+      +--------v--------+      +--------v--------+
           |    Jenkins VM   |      |  SonarQube VM   |      | Azure Bastion   |
           |   (CI/CD)       |      |   (SAST)        |      | (Secure Access) |
           +--------+--------+      +--------+--------+      +-----------------+
                    |                        |
                    |                +-------v-------+
                    |                | PostgreSQL    |
                    |                | Flexible DB   |
                    |                +---------------+
                    |
           +--------v--------+
           |  Nginx Reverse  |
           |  Proxy + SSL    |
           +-----------------+
```

## Current Tools

| Tool | Purpose | Status |
|------|---------|--------|
| Jenkins | CI/CD automation server | Deployed |
| SonarQube | Static Application Security Testing (SAST) | Deployed |
| Nginx | Reverse proxy with Let's Encrypt SSL | Deployed |
| PostgreSQL | Database backend for SonarQube | Deployed |

## Planned Tools

| Tool | Purpose | Status |
|------|---------|--------|
| Trivy | Container vulnerability scanning | Planned |
| Artifactory | Artifact repository management | Planned |
| Harbor | Container registry with security scanning | Planned |

## Project Structure

```
VulnMngm-Pipeline/
├── devops-infrastructure/          # Terraform IaC
│   └── terraform/
│       ├── azure/                  # Azure implementation
│       │   ├── environments/
│       │   │   └── staging/        # Environment-specific configs
│       │   └── modules/
│       │       ├── bastion/        # Azure Bastion for secure access
│       │       ├── compute/        # VM provisioning with encryption
│       │       ├── networking/     # VNet, subnets, and peering
│       │       ├── postgresql_flexible/  # Managed PostgreSQL
│       │       └── security/       # NSG and security rules
│       │
│       └── aws/                    # AWS implementation (planned)
│           ├── environments/
│           │   └── staging/
│           └── modules/
│               ├── bastion/        # AWS Systems Manager Session Manager
│               ├── compute/        # EC2 with EBS encryption
│               ├── networking/     # VPC, subnets, and peering
│               ├── rds/            # RDS PostgreSQL
│               └── security/       # Security Groups
│
├── devops-ansible/                 # Ansible configuration management
│   ├── inventory/                  # Host inventories and variables
│   ├── playbooks/                  # Deployment playbooks
│   └── roles/
│       ├── jenkins/                # Jenkins installation
│       ├── sonarqube/              # SonarQube setup
│       ├── nginx_reverse_proxy/    # SSL termination
│       └── security_baseline/      # OS hardening, fail2ban
│
└── README.md
```

## Cloud Support

| Cloud Provider | Status | Description |
|----------------|--------|-------------|
| Microsoft Azure | Implemented | Full module support with Key Vault, Bastion, Flexible PostgreSQL |
| Amazon Web Services | Planned | Equivalent modules using KMS, Systems Manager, RDS |

The Terraform modules follow a consistent interface pattern, allowing the same Ansible playbooks to configure applications regardless of the underlying cloud provider.

## Technologies

### Infrastructure

- **Cloud Providers**: Microsoft Azure (current), AWS (planned)
- **IaC Tool**: Terraform >= 1.5
- **Configuration Management**: Ansible >= 2.9

### Security Features

- Azure Key Vault for disk encryption keys
- Network Security Groups with explicit deny rules
- Azure Bastion for secure SSH access (no public SSH exposure)
- Fail2ban for intrusion prevention
- Let's Encrypt SSL certificates via Certbot
- Ansible Vault for secrets management

## Quick Start

### Prerequisites

- Azure CLI configured with appropriate permissions
- Terraform >= 1.5
- Ansible >= 2.9
- Python 3.x

### 1. Provision Infrastructure

```bash
cd devops-infrastructure/terraform/azure/environments/staging

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### 2. Configure Applications

```bash
cd devops-ansible

# Setup configuration (see devops-ansible/README.md for details)
cp ansible.cfg.example ansible.cfg
# Edit inventory and variables...

# Deploy all services
ansible-playbook playbooks/site.yml
```

## Documentation

- [Ansible Configuration Guide](devops-ansible/README.md) - Detailed setup and usage instructions

## Roadmap

### Multi-Cloud Support
- [ ] AWS Terraform modules (VPC, EC2, RDS, Security Groups)
- [ ] AWS Systems Manager for secure access (Bastion alternative)
- [ ] AWS KMS for encryption key management

### Security Tools
- [ ] Trivy integration for container scanning in Jenkins pipelines
- [ ] Artifactory deployment for artifact management
- [ ] Harbor registry with Trivy scanner integration

### Monitoring & Observability
- [ ] Prometheus + Grafana for monitoring
- [ ] Security dashboards and alerting

### CPTM8 Integration
- [ ] Jenkins pipeline templates for CPTM8 repositories
- [ ] SonarQube quality gates configuration
- [ ] GitOps workflow with ArgoCD

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [CPTM8](https://github.com/deifzar) - Target application for this DevSecOps pipeline

## Author

[deifzar](https://github.com/deifzar) - DevSecOps infrastructure demonstration project.
