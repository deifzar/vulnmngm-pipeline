# DevSecOps Infrastructure Pipeline

A **cloud-agnostic** Infrastructure as Code (IaC) project demonstrating the deployment of a complete DevSecOps toolchain using Terraform and Ansible. Currently implemented on Azure with AWS support planned.

## Overview

This project showcases proficiency in building production-ready DevOps infrastructure through:

- **Infrastructure Provisioning**: Terraform modules with cloud-agnostic design patterns
- **Configuration Management**: Ansible roles for application deployment and hardening
- **CI/CD Pipelines**: Jenkins Shared Libraries with integrated security scanning (SAST, SCA, SBOM)
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
    +---------------+------------------+-----+------+------------------+---------------+
    |               |                  |            |                  |               |
+---v----+      +---v----+     +-------v-------+  +-v-----------+  +---v-----------+  +----v-----------+
| Jenkins|      |Jenkins |     |  SonarQube VM |  | Artifactory |  | PostgreSQL    |  | Azure Bastion  |
|Controller     | Agent  |     |   (SAST)      |  | (Artifacts) |  | Flexible DB   |  | (Secure Access)|
+---+----+      +---+----+     +-------+-------+  +------+------+  +---------------+  +----------------+
    |               |                  |                 |
    |     +---------+                  |                 |
    |     |                            |                 |
+---v-----v----+               +-------v-------+  +------v------+
|   Nginx      |               |    Nginx      |  |   Nginx     |
| Reverse Proxy|               | Reverse Proxy |  |Reverse Proxy|
|  (WebSocket) |               |    (SSL)      |  |   (SSL)     |
+--------------+               +---------------+  +-------------+
```

**Network Design:**
- Jenkins Controller: Public IP with Nginx reverse proxy (HTTPS + WebSocket)
- Jenkins Agents: Private subnet only, connect to controller via internal network
- SonarQube: Public IP with Nginx reverse proxy (HTTPS)
- Artifactory: Public IP with Nginx reverse proxy (HTTPS)
- PostgreSQL: Private subnet with VNet integration (separate instances for SonarQube and Artifactory)
- SSH access to agents: ProxyCommand through Jenkins Controller

## Current Tools

| Tool | Purpose | Status |
|------|---------|--------|
| Jenkins Controller | CI/CD automation server | Deployed |
| Jenkins Agent | Build execution with Docker | Deployed |
| Jenkins Shared Library | Reusable pipeline templates for microservices | Implemented |
| SonarQube | Static Application Security Testing (SAST) | Deployed |
| Artifactory | Universal artifact repository (Maven, npm, Docker, etc.) | Deployed |
| Trivy | Container/source/IaC vulnerability scanning | Deployed (on agents) |
| Docker | Container runtime on agents | Deployed |
| Nginx | Reverse proxy with SSL + WebSocket | Deployed |
| PostgreSQL | Database backend for SonarQube and Artifactory | Deployed |

## Planned Tools

| Tool | Purpose | Status |
|------|---------|--------|
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
│   ├── inventory/
│   │   ├── staging.ini             # Host inventory with ProxyCommand for agents
│   │   ├── group_vars/
│   │   │   ├── jenkins_controllers.yml
│   │   │   ├── jenkins_agents.yml  # Agent secrets (vault-encrypted)
│   │   │   ├── sonarqube_servers.yml
│   │   │   └── artifactory_servers.yml
│   │   └── host_vars/
│   │       └── artifactory-staging.yml  # Per-host Artifactory config
│   ├── playbooks/
│   │   ├── site.yml                # Master playbook with tags
│   │   ├── deploy_jenkins_controller.yml
│   │   ├── deploy_jenkins_agent.yml
│   │   ├── deploy_sonarqube.yml
│   │   └── deploy_artifactory.yml  # Artifactory deployment
│   └── roles/
│       ├── jenkins/                # Jenkins Controller installation
│       ├── jenkins_agent/          # Agent with Docker, Trivy, systemd service
│       ├── sonarqube/              # SonarQube setup
│       ├── artifactory/            # JFrog Artifactory Pro setup
│       ├── nginx_reverse_proxy/    # SSL + WebSocket proxy
│       └── security_baseline/      # OS hardening, fail2ban
│
├── devops-jenkins-pipeline-libraries/  # Jenkins Shared Libraries (Groovy)
│   └── microservices-lib/
│       ├── vars/
│       │   └── servicePipeline.groovy  # Main pipeline entry point
│       └── src/com/deifzar/ci/
│           ├── BuildStage.groovy       # Go binary & Docker build
│           ├── TestStage.groovy        # Unit testing
│           ├── SASTStage.groovy        # SonarQube integration
│           ├── SCAStage.groovy         # Trivy scanning (source, image, IaC)
│           ├── SBOMStage.groovy        # SBOM export (CycloneDX, SPDX)
│           ├── Docker.groovy           # Docker operations
│           ├── PublishStage.groovy     # Artifact publishing
│           └── providers/
│               ├── GitHubProvider.groovy
│               └── GitLabProvider.groovy
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
- PostgreSQL Flexible Server with SSL/TLS encryption (private VNet access only)
- Audit logging enabled for Artifactory

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

# Deploy specific components using tags
ansible-playbook playbooks/site.yml --tags jenkins_controller
ansible-playbook playbooks/site.yml --tags jenkins_agent
ansible-playbook playbooks/site.yml --tags sonarqube
ansible-playbook playbooks/site.yml --tags artifactory

# Deploy all Jenkins components (controller + agents)
ansible-playbook playbooks/site.yml --tags jenkins
```

## Documentation

- [Ansible Configuration Guide](devops-ansible/README.md) - Detailed setup and usage instructions

## Component Details

### Jenkins Shared Library

A reusable Jenkins Shared Library for microservices CI/CD pipelines with integrated security scanning.

**Location:** `devops-jenkins-pipeline-libraries/microservices-lib/`

**Pipeline Stages:**
```
Checkout → Build Go Binary → Test → SAST → Build Docker → SCA → SBOM → Publish
```

**Security Features:**
| Stage | Tool | Description |
|-------|------|-------------|
| SAST | SonarQube | Static code analysis with quality gates |
| SCA (Source) | Trivy | Vulnerability scan of source code dependencies |
| SCA (Image) | Trivy | Container image vulnerability scanning |
| SCA (IaC) | Trivy | Infrastructure-as-Code misconfiguration detection |
| SBOM | Trivy | Software Bill of Materials (CycloneDX & SPDX formats) |

**Supported SCM Providers:**
- GitHub (with GHCR registry)
- GitLab (with GitLab Container Registry)

**Usage Example (Jenkinsfile):**
```groovy
@Library('microservices-lib') _

servicePipeline {
    scmProvider           = 'github'
    serviceName           = 'my-service'
    gitCredentialsId      = 'github-credentials'
    runTests              = true
    runSASTScan           = true
    sonarqubeUrl          = 'https://sonarqube.example.com'
    sonarqubeCredentialsId = 'sonarqube-token'
    runTrivyImageScan     = true
    trivySeverity         = 'HIGH,CRITICAL'
}
```

### JFrog Artifactory

Artifactory is deployed as a universal artifact repository supporting multiple package formats (Maven, npm, Docker, PyPI, etc.).

**Configuration highlights:**
- PostgreSQL backend with SSL encryption
- Systemd service with optimized file descriptor limits
- JVM tuning (2GB-4GB heap)
- Nginx reverse proxy with HTTPS
- Audit logging enabled

**Post-deployment setup (via Web GUI):**
1. Complete the setup wizard at `https://artifactory-domain`
2. Configure repositories (local, remote, virtual)
3. Set up users, groups, and permissions
4. Configure LDAP/SSO if required
5. Set up replication for HA (optional)

## Roadmap

### Multi-Cloud Support
- [ ] AWS Terraform modules (VPC, EC2, RDS, Security Groups)
- [ ] AWS Systems Manager for secure access (Bastion alternative)
- [ ] AWS KMS for encryption key management

### Security Tools
- [x] Trivy installed on Jenkins agents for container scanning
- [x] Trivy integration in Jenkins pipelines (source, image, IaC scanning)
- [x] SBOM generation (CycloneDX & SPDX formats)
- [x] Artifactory deployment for artifact management
- [ ] Harbor registry with Trivy scanner integration

### Monitoring & Observability
- [ ] Prometheus + Grafana for monitoring
- [ ] Security dashboards and alerting

### CPTM8 Integration
- [x] Jenkins pipeline templates for CPTM8 repositories (microservices-lib)
- [x] SonarQube quality gates configuration (integrated in pipeline)
- [ ] GitOps workflow with ArgoCD

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [CPTM8](https://github.com/deifzar) - Target application for this DevSecOps pipeline

## Author

[deifzar](https://github.com/deifzar) - DevSecOps infrastructure demonstration project.
