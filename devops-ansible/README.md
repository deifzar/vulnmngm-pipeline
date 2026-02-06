# DevOps Ansible Configuration

Ansible automation for deploying and configuring DevOps infrastructure including Jenkins (Controller + Agents), SonarQube, and supporting security tools.

## Prerequisites

- Ansible 2.9+
- SSH access to target servers
- Python 3.x on target hosts

## Project Structure

```
devops-ansible/
├── ansible.cfg                 # Ansible configuration (create from .example)
├── inventory/
│   ├── staging.ini             # Staging inventory (create from .example)
│   ├── production.ini          # Production inventory (create from .example)
│   └── group_vars/
│       ├── all/
│       │   ├── vars.yml        # Global variables (create from .example)
│       │   └── vault.yml       # Encrypted secrets (create with ansible-vault)
│       ├── jenkins_controllers.yml   # Controller-specific vars
│       ├── jenkins_agents.yml        # Agent vars (secrets, controller FQDN)
│       └── sonarqube_servers.yml
├── playbooks/
│   ├── site.yml                      # Master playbook with tags
│   ├── deploy_jenkins_controller.yml # Jenkins Controller deployment
│   ├── deploy_jenkins_agent.yml      # Jenkins Agent deployment
│   └── deploy_sonarqube.yml          # SonarQube deployment
└── roles/
    ├── common/                 # Common server setup
    ├── security_baseline/      # Security hardening
    ├── nginx_reverse_proxy/    # Nginx reverse proxy with SSL + WebSocket
    ├── jenkins/                # Jenkins Controller
    ├── jenkins_agent/          # Jenkins Agent (Docker, Trivy, systemd service)
    └── sonarqube/              # SonarQube code analysis
```

## Initial Setup

### 1. Copy Configuration Templates

```bash
# Copy all example files to their actual names
cp ansible.cfg.example ansible.cfg
cp inventory/staging.ini.example inventory/staging.ini
cp inventory/production.ini.example inventory/production.ini
cp inventory/group_vars/jenkins_controllers.yml.example inventory/group_vars/jenkins_controllers.yml
cp inventory/group_vars/jenkins_agents.yml.example inventory/group_vars/jenkins_agents.yml
cp inventory/group_vars/sonarqube_servers.yml.example inventory/group_vars/sonarqube_servers.yml
mkdir -p inventory/group_vars/all
cp inventory/group_vars/all/vars.yml.example inventory/group_vars/all/vars.yml
```

### 2. Create Vault Password File

```bash
# Create the vault password file (replace with your secure password)
echo 'your-secure-vault-password' > .ansible_devops_vault_pass
chmod 600 .ansible_devops_vault_pass
```

### 3. Create Encrypted Vault

```bash
# Create the vault for storing secrets
ansible-vault create inventory/group_vars/all/vault.yml
```

Add your secrets in the vault (see `vault.yml.example` for structure):

```yaml
vault_sonarqube_db_password: "your-database-password"
vault_jenkins_agent_secret: "your-jenkins-agent-secret"  # From Jenkins Controller UI
```

### 4. Configure Your Environment

Edit the copied files and replace placeholders with your actual values:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `<JENKINS_CONTROLLER_IP>` | Jenkins Controller public IP | `10.0.1.10` |
| `<JENKINS_AGENT_PRIVATE_IP>` | Jenkins Agent private IP | `10.0.1.4` |
| `<SONARQUBE_PUBLIC_IP>` | SonarQube server IP | `10.0.1.11` |
| `<SSH_USERNAME>` | SSH user for connection | `azureadmin` |
| `<PATH_TO_SSH_PRIVATE_KEY>` | Path to SSH key | `~/.ssh/id_rsa` |
| `<JENKINS_FQDN>` | Jenkins domain name | `jenkins.example.com` |
| `<JENKINS_CONTROLLER_INTERNAL_IP>` | Controller private IP for agents | `10.0.1.5` |
| `<SONARQUBE_FQDN>` | SonarQube domain name | `sonarqube.example.com` |
| `<DATABASE_HOSTNAME>` | Database server hostname | `db.example.com` |
| `<DATABASE_USERNAME>` | Database username | `sonarqube` |
| `<YOUR_PUBLIC_IP>` | Your IP for SSH access | `203.0.113.50` |
| `<YOUR_EMAIL>` | Email for SSL certs | `admin@example.com` |

## Usage

### Test Connectivity

```bash
ansible all -m ping
```

### Deploy Everything (Staging)

```bash
ansible-playbook playbooks/site.yml
```

### Deploy Using Tags

The `site.yml` playbook supports tags for selective deployment:

```bash
# Deploy Jenkins Controller only
ansible-playbook playbooks/site.yml --tags jenkins_controller

# Deploy Jenkins Agents only
ansible-playbook playbooks/site.yml --tags jenkins_agent

# Deploy all Jenkins components (controller + agents)
ansible-playbook playbooks/site.yml --tags jenkins

# Deploy SonarQube only
ansible-playbook playbooks/site.yml --tags sonarqube
```

### Deploy Specific Playbooks

```bash
# Deploy Jenkins Controller
ansible-playbook playbooks/deploy_jenkins_controller.yml

# Deploy Jenkins Agent
ansible-playbook playbooks/deploy_jenkins_agent.yml

# Deploy SonarQube
ansible-playbook playbooks/deploy_sonarqube.yml
```

### Deploy to Production

```bash
ansible-playbook -i inventory/production.ini playbooks/site.yml
```

### Dry Run (Check Mode)

```bash
ansible-playbook playbooks/site.yml --check --diff
```

## Vault Operations

```bash
# Edit vault
ansible-vault edit inventory/group_vars/all/vault.yml

# View vault contents
ansible-vault view inventory/group_vars/all/vault.yml

# Change vault password
ansible-vault rekey inventory/group_vars/all/vault.yml
```

## Roles

| Role | Description |
|------|-------------|
| `common` | Base packages, users, and system configuration |
| `security_baseline` | SSH hardening, firewall, fail2ban |
| `nginx_reverse_proxy` | Nginx with SSL/TLS + WebSocket proxy support |
| `jenkins` | Jenkins Controller installation and configuration |
| `jenkins_agent` | Jenkins Agent with Docker, Trivy, and systemd service |
| `sonarqube` | SonarQube server with PostgreSQL integration |

### Jenkins Agent Role Details

The `jenkins_agent` role installs:
- **Java 21** (OpenJDK JRE)
- **Docker Engine** with buildx and compose plugins
- **Trivy** for container vulnerability scanning
- **Systemd service** for automatic agent startup

The agent connects to the controller via WebSocket using a secret stored in Ansible Vault.

## Jenkins Agent SSH Access

Jenkins Agents are on a private subnet without public IPs. SSH access is provided through the Jenkins Controller using `ProxyCommand`:

```ini
[jenkins_agents]
jenkins-agent-staging ansible_host=10.0.1.4 ansible_user=azureadmin \
    ansible_ssh_common_args='-o ForwardAgent=yes -o ProxyCommand="ssh -W %h:%p -i <KEY_PATH> <USER>@<CONTROLLER_FQDN>"'
```

This configuration:
- Uses the Jenkins Controller as a bastion/jump host
- Forwards the SSH connection to the agent's private IP
- Requires the SSH key path in the ProxyCommand (agent forwarding alone isn't sufficient)

## Security Notes

- Never commit files containing sensitive data (IPs, passwords, keys)
- The `.gitignore` excludes all sensitive configuration files
- Only `*.example` templates are safe to commit
- Keep your vault password secure and never commit it
- Use strong, unique passwords for all services

## Troubleshooting

### Vault Password Error

```
ERROR! A vault password must be specified to decrypt data
```

Ensure `.ansible_devops_vault_pass` exists and contains the correct password.

### Variable Undefined Error

```
'vault_sonarqube_db_password' is undefined
```

Ensure the vault file is in the correct location (`inventory/group_vars/all/vault.yml`) and contains the required variable.

### SSH Connection Issues

```bash
# Test SSH manually
ssh -i <PATH_TO_KEY> <USER>@<HOST>

# Run with verbose output
ansible-playbook playbooks/site.yml -vvv
```
