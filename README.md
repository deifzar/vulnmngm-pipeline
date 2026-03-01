# DevSecOps Infrastructure Pipeline

A **multi-cloud** Infrastructure as Code (IaC) project demonstrating the deployment of a complete DevSecOps toolchain using Terraform and Ansible. Fully implemented on both **Azure** and **AWS**.

## Overview

This project showcases proficiency in building production-ready DevOps infrastructure through:

- **Infrastructure Provisioning**: Terraform modules with cloud-agnostic design patterns
- **Configuration Management**: Ansible roles for application deployment and hardening
- **CI/CD Pipelines**: Jenkins Shared Libraries with integrated security scanning (SAST, SCA, SBOM)
- **Artifact Management**: JFrog Artifactory integration with promotion workflows
- **Security-First Design**: Network segmentation, encryption, and security baselines
- **Multi-Cloud Strategy**: Full support for both Azure and AWS

## CPTM8 Project Integration

This DevSecOps infrastructure is designed to support the [CPTM8 project](https://github.com/deifzar), implementing a **shift-left security** approach that integrates security practices early in the development lifecycle:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Shift-Left Security Pipeline                         │
├─────────────┬─────────────┬─────────────┬─────────────┬─────────────────────┤
│    Code     │    Build    │    Test     │   Deploy    │      Monitor        │
├─────────────┼─────────────┼─────────────┼─────────────┼─────────────────────┤
│ SonarQube   │ Trivy       │ DAST        │ Artifactory │ Prometheus          │
│ (SAST)      │ (Container  │ (Dynamic    │ (Artifact   │ Grafana             │
│             │  Scanning)  │  Analysis)  │  Repository)│                     │
│ Pre-commit  │ Snyk        │ Pen Testing │ Promotion   │ Security            │
│ Hooks       │ (SCA)       │             │ Workflow    │ Dashboards          │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────────────┘
```

**Key Integration Points:**

- **Early Vulnerability Detection**: SonarQube scans CPTM8 code on every commit
- **Container Security**: Trivy and Snyk ensure secure container images
- **Automated CI/CD**: Jenkins pipelines with built-in security gates
- **Artifact Management**: Artifactory with environment-based promotion (dev → staging → release)
- **PR/MR Status Checks**: Granular per-stage status reporting to GitHub/GitLab

## Architecture

### Azure Architecture

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

### AWS Architecture

```
                                    +------------------+
                                    |    AWS Cloud     |
                                    +--------+---------+
                                             |
    +---------------+------------------+-----+------+------------------+---------------+
    |               |                  |            |                  |               |
+---v----+      +---v----+     +-------v-------+  +-v-----------+  +---v-----------+  +----v-----------+
| Jenkins|      |Jenkins |     |  SonarQube    |  | Artifactory |  |  RDS          |  |   ALB          |
|Controller     | Agent  |     |   EC2         |  |   EC2       |  | PostgreSQL    |  | (Optional)     |
+---+----+      +---+----+     +-------+-------+  +------+------+  +---------------+  +----------------+
    |               |                  |                 |                |
    |               |                  |                 |                |
+---v---------------v------------------v-----------------v----------------v-----------+
|                           VPC with Public/Private/Database Subnets                  |
|                                                                                     |
|  +-------------+  +----------------+  +-------------------+  +------------------+   |
|  | KMS Keys    |  | Secrets Manager|  | Security Groups   |  | IAM Roles        |   |
|  | (Encryption)|  | (DB Passwords) |  | (Network Security)|  | (Instance Profiles)  |
|  +-------------+  +----------------+  +-------------------+  +------------------+   |
+-------------------------------------------------------------------------------------+
```

**Network Design:**
- Jenkins Controller: Public/Private subnet (ALB optional) with Nginx reverse proxy
- Jenkins Agents: Private subnet only, connect to controller via JNLP
- SonarQube: Public/Private subnet with Nginx reverse proxy (HTTPS)
- Artifactory: Public/Private subnet with Nginx reverse proxy (HTTPS)
- Database: Private subnet with VNet/VPC integration
- SSH access: Via bastion (Azure) or direct with IP allowlist (AWS)

## Current Tools

| Tool | Purpose | Azure | AWS |
|------|---------|-------|-----|
| Jenkins Controller | CI/CD automation server | ✅ | ✅ |
| Jenkins Agent | Build execution with Docker | ✅ | ✅ |
| Jenkins Shared Library | Reusable pipeline templates | ✅ | ✅ |
| SonarQube | Static Application Security Testing (SAST) | ✅ | ✅ |
| Artifactory | Universal artifact repository | ✅ | ✅ |
| Trivy | Container/source/IaC vulnerability scanning | ✅ | ✅ |
| Snyk | SCA scanning (source code) | ✅ | ✅ |
| Docker | Container runtime on agents | ✅ | ✅ |
| Nginx | Reverse proxy with SSL + WebSocket | ✅ | ✅ |
| PostgreSQL | Database backend (Flexible/RDS) | ✅ | ✅ |

## Planned Tools

| Tool | Purpose | Status |
|------|---------|--------|
| Harbor | Container registry with security scanning | Planned |
| Prometheus + Grafana | Monitoring and observability | Planned |

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
│       │       ├── keyvault/       # Azure Key Vault for secrets
│       │       ├── networking/     # VNet, subnets, and peering
│       │       ├── postgresql_flexible/  # Managed PostgreSQL
│       │       └── security/       # NSG and security rules
│       │
│       └── aws/                    # AWS implementation ✅ NEW
│           ├── environments/
│           │   └── staging/
│           └── modules/
│               ├── alb/            # Application Load Balancer
│               ├── compute/        # EC2 with EBS encryption
│               ├── iam/            # IAM roles and instance profiles
│               ├── kms/            # KMS for encryption keys
│               ├── networking/     # VPC, subnets, NAT Gateway
│               ├── rds/            # RDS PostgreSQL
│               ├── secretsmanager/ # AWS Secrets Manager
│               └── security/       # Security Groups
│
├── devops-ansible/                 # Ansible configuration management
│   ├── inventory/
│   │   ├── staging.ini             # Host inventory
│   │   ├── group_vars/
│   │   │   ├── all/vars.yml        # Common variables
│   │   │   ├── jenkins_controllers.yml
│   │   │   ├── jenkins_agents.yml
│   │   │   ├── sonarqube_servers.yml
│   │   │   └── artifactory_servers.yml
│   │   └── host_vars/
│   ├── playbooks/
│   │   ├── site.yml                # Master playbook with tags
│   │   ├── deploy_jenkins_controller.yml
│   │   ├── deploy_jenkins_agent.yml
│   │   ├── deploy_sonarqube.yml
│   │   └── deploy_artifactory.yml
│   └── roles/
│       ├── common/                 # Common OS setup
│       ├── jenkins/                # Jenkins Controller installation
│       ├── jenkins_agent/          # Agent with Docker, Trivy
│       ├── sonarqube/              # SonarQube setup
│       ├── artifactory/            # JFrog Artifactory Pro
│       ├── nginx_reverse_proxy/    # SSL + WebSocket proxy
│       └── security_baseline/      # OS hardening, fail2ban
│
├── devops-jenkins-pipeline-libraries/  # Jenkins Shared Libraries
│   ├── src/com/deifzar/ci/
│   │   ├── Artifactory.groovy      # ✅ NEW: JFrog CLI integration
│   │   ├── BuildStage.groovy       # Multi-language build methods
│   │   ├── Docker.groovy           # Docker operations
│   │   ├── SASTStage.groovy        # SonarQube: CLI, Gradle, Maven
│   │   ├── SBOMStage.groovy        # SBOM generation (SPDX, CycloneDX)
│   │   ├── SCAStage.groovy         # Trivy & Snyk scanning
│   │   ├── TestStage.groovy        # Multi-language test methods
│   │   └── providers/
│   │       ├── GitHubProvider.groovy  # GitHub status + PR creation
│   │       └── GitLabProvider.groovy  # GitLab status + MR creation
│   └── vars/
│       ├── golangPipeline.groovy      # Go microservices
│       ├── gradlePipeline.groovy      # Gradle/Java projects
│       ├── gradleAndroidPipeline.groovy # ✅ NEW: Android apps
│       ├── mavenPipeline.groovy       # Maven projects
│       └── promotionPipeline.groovy   # ✅ NEW: Artifact promotion
│
└── README.md
```

## Cloud Support

| Cloud Provider | Status | Features |
|----------------|--------|----------|
| Microsoft Azure | ✅ Implemented | Key Vault, Bastion, Flexible PostgreSQL, NSGs |
| Amazon Web Services | ✅ Implemented | KMS, ALB, RDS, Secrets Manager, Security Groups |

The Terraform modules follow a consistent interface pattern, allowing the same Ansible playbooks to configure applications regardless of the underlying cloud provider.

## Jenkins Shared Library

### Available Pipelines

| Pipeline | Language/Framework | Features |
|----------|-------------------|----------|
| `golangPipeline` | Go | Build, Test, SAST, SCA, SBOM, Artifactory |
| `gradlePipeline` | Java/Kotlin (Gradle) | Build, Test, SAST, SCA, SBOM |
| `gradleAndroidPipeline` | Android (Gradle) | Build, Test, SAST, SCA, SBOM |
| `mavenPipeline` | Java (Maven) | Build, Test, SAST, SCA, SBOM |
| `promotionPipeline` | N/A | Artifact promotion with approval gates |

### Pipeline Stages

```
┌──────────┐   ┌───────┐   ┌──────┐   ┌──────┐   ┌─────┐   ┌──────┐   ┌────────────┐
│ Checkout │ → │ Build │ → │ Test │ → │ SAST │ → │ SCA │ → │ SBOM │ → │ Artifactory│
└──────────┘   └───────┘   └──────┘   └──────┘   └─────┘   └──────┘   └────────────┘
                  │                                                          │
                  ▼                                                          ▼
            ┌──────────┐                                              ┌──────────┐
            │ Go Binary│                                              │ Promote  │
            │ + Docker │                                              │ (Manual) │
            └──────────┘                                              └──────────┘
```

### Security Scanning Features

| Stage | Tool | Description |
|-------|------|-------------|
| SAST | SonarQube | Static code analysis with quality gates |
| SCA (Source) | Trivy | Vulnerability scan of source code dependencies |
| SCA (Source) | Snyk | Additional dependency vulnerability scanning |
| SCA (Image) | Trivy | Container image vulnerability scanning |
| SCA (IaC) | Trivy | Dockerfile misconfiguration detection |
| SBOM | Trivy | Software Bill of Materials (CycloneDX & SPDX) |

### Artifactory Integration

The pipeline library includes full JFrog Artifactory integration:

- **Upload artifacts**: Binaries, SCA reports, SBOMs
- **Push Docker images**: Tagged and pushed with build metadata
- **Promotion workflow**: Promote artifacts between environments (dev → staging → release)
- **Build info**: Collects Git info and environment variables

### PR/MR Status Checks

Granular status reporting to GitHub PRs or GitLab MRs:

```
✅ CI/Build-GoBinary - Build Go binary passed
✅ CI/Build-Docker - Build docker passed
✅ CI/Test - Tests passed
❌ CI/SAST - SAST failed
✅ CI/SCA-Trivy-Source - SCA - Trivy source code passed
✅ CI/SCA-Trivy-Image - SCA - Trivy image scan passed
✅ CI/SCA-Trivy-Dockerfile - SCA - Trivy dockerfile passed
✅ CI/SCA-Snyk-Source - SCA - Snyk source code passed
✅ CI/SBOM-Trivy - SBOM - Trivy passed
❌ CI/Pipeline - Pipeline failed
```

### Usage Example (Jenkinsfile)

```groovy
@Library('devops-pipeline-libraries') _

golangPipeline {
    scmProvider           = 'github'
    repoName              = 'my-service'
    gitCredentialsId      = 'github-app-jenkins'

    // Enable stages
    runTest               = true
    runSAST               = true
    runSCA                = true
    runSBOM               = true
    runPublish            = true

    // SonarQube
    sonarqubeUrl          = 'https://sonarqube.example.com'
    sonarqubeCredentialsId = 'sonarqube-token'

    // Trivy/Snyk settings
    trivyThreshold        = 'HIGH,CRITICAL'
    snykThreshold         = 'high'
    snykCredentialsId     = 'snyk-token'

    // Artifactory
    artifactoryUrl        = 'https://artifactory.example.com'
    artifactoryUsername   = 'jenkins'
    artifactoryCredentialsId = 'artifactory-token'
    artifactoryGenericRepo = 'my-generic'
    artifactoryDockerRepo = 'my-docker'
}
```

### Promotion Pipeline Example

```groovy
@Library('devops-pipeline-libraries') _

promotionPipeline {
    repoName              = 'my-service'
    artifactoryUrl        = 'https://artifactory.example.com'
    artifactoryUsername   = 'jenkins'
    artifactoryCredentialsId = 'artifactory-token'
    artifactoryGenericRepo = 'my-generic'
    artifactoryDockerRepo = 'my-docker'
}
```

Triggered manually with parameters:
- `BUILD_NUMBER`: Build to promote
- `SOURCE_ENV`: Source environment (dev, staging)
- `TARGET_ENV`: Target environment (staging, release)
- `JIRA_TICKET`: Change ticket for audit trail

## AWS Infrastructure Details

### Modules

| Module | Description |
|--------|-------------|
| `networking` | VPC, public/private/database subnets, NAT Gateway, route tables |
| `security` | Security Groups with configurable ingress/egress rules |
| `compute` | EC2 instances with EBS encryption, Elastic IPs |
| `rds` | RDS PostgreSQL with encryption, backups, CloudWatch logs |
| `kms` | KMS keys for EBS and RDS encryption |
| `iam` | IAM roles, policies, and instance profiles for EC2 |
| `secretsmanager` | AWS Secrets Manager for database passwords |
| `alb` | Application Load Balancer with target groups and host-based routing |

### Security Features

- **KMS encryption** for all EBS volumes and RDS instances
- **Security Groups** with explicit allow rules for SSH, HTTP/HTTPS, JNLP
- **Private subnets** for Jenkins agents and RDS
- **ALB (optional)** for centralized HTTPS termination and routing
- **IAM instance profiles** with least-privilege access to Secrets Manager
- **GitHub webhook IP allowlisting** for Jenkins

### Quick Start (AWS)

```bash
cd devops-infrastructure/terraform/aws/environments/staging

# Configure variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Azure Infrastructure Details

### Security Features

- Azure Key Vault for disk encryption keys
- Network Security Groups with explicit deny rules
- Azure Bastion for secure SSH access (no public SSH exposure)
- Fail2ban for intrusion prevention
- Let's Encrypt SSL certificates via Certbot
- Ansible Vault for secrets management
- PostgreSQL Flexible Server with SSL/TLS encryption

### Quick Start (Azure)

```bash
cd devops-infrastructure/terraform/azure/environments/staging

# Initialize and apply
terraform init
terraform plan
terraform apply
```

## Ansible Configuration

```bash
cd devops-ansible

# Setup configuration
cp ansible.cfg.example ansible.cfg
cp inventory/group_vars/all/vars.yml.example inventory/group_vars/all/vars.yml

# Deploy all services
ansible-playbook playbooks/site.yml

# Deploy specific components using tags
ansible-playbook playbooks/site.yml --tags jenkins_controller
ansible-playbook playbooks/site.yml --tags jenkins_agent
ansible-playbook playbooks/site.yml --tags sonarqube
ansible-playbook playbooks/site.yml --tags artifactory

# Deploy all Jenkins components
ansible-playbook playbooks/site.yml --tags jenkins
```

## Roadmap

### Completed ✅

- [x] Azure Terraform modules (VNet, VMs, PostgreSQL Flexible, Key Vault)
- [x] AWS Terraform modules (VPC, EC2, RDS, KMS, ALB, Secrets Manager)
- [x] Jenkins Shared Library with multi-language support
- [x] Trivy integration (source, image, IaC scanning)
- [x] Snyk integration for SCA
- [x] SBOM generation (CycloneDX & SPDX formats)
- [x] JFrog Artifactory deployment and integration
- [x] Artifact promotion workflow (dev → staging → release)
- [x] Granular PR/MR status reporting
- [x] Android pipeline support

### In Progress 🚧

- [ ] Harbor registry with Trivy scanner integration

### Planned 📋

- [ ] Prometheus + Grafana for monitoring
- [ ] Security dashboards and alerting
- [ ] GitOps workflow with ArgoCD
- [ ] DAST integration (OWASP ZAP)

## Technologies

### Infrastructure
- **Cloud Providers**: Microsoft Azure, Amazon Web Services
- **IaC Tool**: Terraform >= 1.5
- **Configuration Management**: Ansible >= 2.9

### CI/CD
- **Automation**: Jenkins with Docker agents
- **Pipelines**: Groovy-based Shared Libraries
- **SCM**: GitHub, GitLab

### Security
- **SAST**: SonarQube
- **SCA**: Trivy, Snyk
- **SBOM**: CycloneDX, SPDX
- **Artifacts**: JFrog Artifactory

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [CPTM8](https://github.com/deifzar) - Target application for this DevSecOps pipeline

## Author

[deifzar](https://github.com/deifzar) - DevSecOps infrastructure demonstration project.
