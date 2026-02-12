terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  # Disable auto-registration of resource providers (for azurerm 3.x)
  # You may need to manually register required providers (see below)
  skip_provider_registration = true

  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = false
    }
  }
}

# Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "devsecops" {
  name     = "rg-devsecops-${var.environment}"
  location = var.location

  tags = var.tags
}

# Key Vault for disk encryption
resource "azurerm_key_vault" "disk_encryption" {
  name                        = "kv-devsecops-${var.environment}"
  location                    = azurerm_resource_group.devsecops.location
  resource_group_name         = azurerm_resource_group.devsecops.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enabled_for_disk_encryption = true
  purge_protection_enabled    = true

  tags = var.tags
}

# Key Vault Access Policy for current user
resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.disk_encryption.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Purge"
  ]
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  vnet_name           = "vnet-devsecops-${var.environment}"
  vnet_address_space  = ["10.0.0.0/16"]

  subnets = {
    "subnet-devsecops" = {
      address_prefix    = "10.0.1.0/24"
      service_endpoints = ["Microsoft.KeyVault"]
    },
    "AzureBastionSubnet" = {
      address_prefix    = "10.0.2.0/27"
      service_endpoints = []
    },
    "subnet-postgresql" = {
      address_prefix    = "10.0.3.0/28"
      service_endpoints = []
      delegation = {
        postgresql = {
          name = "delegation-postgres"
          service_delegation = {
            name    = "Microsoft.DBforPostgreSQL/flexibleServers"
            actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
          }
        }
      }
    },
  }

  tags = var.tags
}

# Security Module (NSG)
module "security_web" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  nsg_name            = "nsg-devsecops-with-web-${var.environment}"

  security_rules = merge(
    # HTTPS from devops subnet
    {
      "AllowHTTPSDevSecOps" = {
        priority                   = 750
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = module.networking.subnet_address_prefixes["subnet-devsecops"]
        destination_address_prefix = "*"
        description                = "Allow HTTPS from devsecops subnet"
      }
    },
    # Bastion access (conditional)
    var.enable_bastion ? {
      "AllowBastionInbound" = {
        priority                   = 800
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = module.networking.subnet_address_prefixes["AzureBastionSubnet"]
        destination_address_prefix = "*"
        description                = "Allow SSH from Azure Bastion"
      }
    } : {},
    # SSH from specific IP
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        priority                   = 900 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow SSH from authorized IP"
      }
    },
    # HTTPS from specific IP
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        priority                   = 1000 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow HTTPS from authorized IP"
      }
    },
    # Allow HTTP 80 all
    {
      "AllowHTTPAll" = {
        priority                   = 3000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Allow HTTP for all. Reason: let's encrypt"
      }
    },
    # Explicit deny all
    {
      "DenyAllInbound" = {
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Deny all other inbound traffic"
      }
    }
  )

  tags = var.tags
}

module "security_jenkins_controller" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  nsg_name            = "nsg-devsecops-with-jenkins-controller-${var.environment}"

  security_rules = merge(
    # TCP 50000 from subnet-devsecops
    {
      "AllowDevSecOpsInbound" = {
        priority                   = 700
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "50000"
        source_address_prefix      = module.networking.subnet_address_prefixes["subnet-devsecops"]
        destination_address_prefix = "*"
        description                = "Allow TCP connections from Subnet DevSecOps"
      }
    },
    # HTTPS from devops subnet
    {
      "AllowHTTPSDevSecOps" = {
        priority                   = 750
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = module.networking.subnet_address_prefixes["subnet-devsecops"]
        destination_address_prefix = "*"
        description                = "Allow HTTPS from devsecops subnet"
      }
    },
    # Bastion access (conditional)
    var.enable_bastion ? {
      "AllowBastionInbound" = {
        priority                   = 800
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = module.networking.subnet_address_prefixes["AzureBastionSubnet"]
        destination_address_prefix = "*"
        description                = "Allow SSH from Azure Bastion"
      }
    } : {},
    # SSH from specific IP
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        priority                   = 900 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow SSH from authorized IP"
      }
    },
    # HTTPS from specific IP
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        priority                   = 1000 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow HTTPS from authorized IP"
      }
    },
    # HTTPS from GitHub Hooks
    {
      for idx, ip in var.allowed_https_source_github_hooks_ips : "AllowHTTPS-GitHub-${idx}" => {
        priority                   = 2000 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow HTTPS from authorized GitHub Hooks IP"
      }
    },
    # Allow HTTP 80 all
    {
      "AllowHTTPAll" = {
        priority                   = 3000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Allow HTTP for all. Reason: let's encrypt"
      }
    },
    # Explicit deny all
    {
      "DenyAllInbound" = {
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Deny all other inbound traffic"
      }
    }
  )

  tags = var.tags
}

# Security Module (NSG)
module "security_jenkins_agent" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  nsg_name            = "nsg-devsecops-jenkins-agent-${var.environment}"

  security_rules = merge(
    # Jenkins Node access
    {
      "AllowDevSecOpsInbound" = {
        priority                   = 700
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = module.networking.subnet_address_prefixes["subnet-devsecops"]
        destination_address_prefix = "*"
        description                = "Allow SSH from Subnet DevSecOps"
      }
    },
    # Bastion access (conditional)
    var.enable_bastion ? {
      "AllowBastionInbound" = {
        priority                   = 800
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = module.networking.subnet_address_prefixes["AzureBastionSubnet"]
        destination_address_prefix = "*"
        description                = "Allow SSH from Azure Bastion"
      }
    } : {},
    # Explicit deny all
    {
      "DenyAllInbound" = {
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Deny all other inbound traffic"
      }
    }
  )

  tags = var.tags
}

module "security_artifactory" {
  source = "../../modules/security"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  nsg_name            = "nsg-devsecops-with-artifactory-${var.environment}"

  security_rules = merge(
    # HTTPS from devops subnet
    {
      "AllowHTTPSDevSecOps" = {
        priority                   = 750
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = module.networking.subnet_address_prefixes["subnet-devsecops"]
        destination_address_prefix = "*"
        description                = "Allow HTTPS from devsecops subnet"
      }
    },
    # Bastion access (conditional)
    var.enable_bastion ? {
      "AllowBastionInbound" = {
        priority                   = 800
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = module.networking.subnet_address_prefixes["AzureBastionSubnet"]
        destination_address_prefix = "*"
        description                = "Allow SSH from Azure Bastion"
      }
    } : {},
    # SSH from specific IP
    {
      for idx, ip in var.allowed_ssh_source_ips : "AllowSSH-${idx}" => {
        priority                   = 900 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow SSH from authorized IP"
      }
    },
    # HTTPS from specific IP
    {
      for idx, ip in var.allowed_https_source_ips : "AllowHTTPS-${idx}" => {
        priority                   = 1000 + idx
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = ip
        destination_address_prefix = "*"
        description                = "Allow HTTPS from authorized IP"
      }
    },
    # Allow HTTP 80 all
    {
      "AllowHTTPAll" = {
        priority                   = 3000
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Allow HTTP for all. Reason: let's encrypt"
      }
    },
    # Explicit deny all
    {
      "DenyAllInbound" = {
        priority                   = 4096
        direction                  = "Inbound"
        access                     = "Deny"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
        description                = "Deny all other inbound traffic"
      }
    }
  )

  tags = var.tags
}

# Azure Bastion Module (conditional)
module "bastion" {
  count  = var.enable_bastion ? 1 : 0
  source = "../../modules/bastion"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  bastion_name        = "bastion-devsecops-${var.environment}"
  bastion_subnet_id   = module.networking.subnet_ids["AzureBastionSubnet"]
  public_ip_name      = "pip-bastion-${var.environment}"
  sku                 = "Basic"

  tags = var.tags
}

# Jenkins Built-in Node VM
module "jenkins_controller_vm" {
  source = "../../modules/compute"

  resource_group_name    = azurerm_resource_group.devsecops.name
  location               = azurerm_resource_group.devsecops.location
  vm_name                = "vm-jenkins-controller-${var.environment}"
  vm_size                = "Standard_D2s_v3"
  admin_username         = "azureadmin"
  ssh_public_key         = file(var.ssh_public_key_path)
  subnet_id              = module.networking.subnet_ids["subnet-devsecops"]
  nsg_id                 = module.security_jenkins_controller.nsg_id
  create_public_ip       = true
  public_ip_dns_name     = "jenkins-controller-cptm8net"
  os_disk_size_gb        = 50
  os_disk_storage_type   = "Premium_LRS"
  enable_disk_encryption = true
  key_vault_id           = azurerm_key_vault.disk_encryption.id
  key_vault_name         = azurerm_key_vault.disk_encryption.name

  tags = merge(var.tags, {
    Service = "Jenkins Controller"
    Role    = "CI/CD"
  })

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# Jenkins Agent VM
module "jenkins_agent_vm" {
  source = "../../modules/compute"

  resource_group_name    = azurerm_resource_group.devsecops.name
  location               = azurerm_resource_group.devsecops.location
  vm_name                = "vm-jenkins-agent-${var.environment}"
  vm_size                = "Standard_D2s_v3"
  admin_username         = "azureadmin"
  ssh_public_key         = file(var.ssh_public_key_path)
  subnet_id              = module.networking.subnet_ids["subnet-devsecops"]
  nsg_id                 = module.security_jenkins_agent.nsg_id
  create_public_ip       = false
  os_disk_size_gb        = 50
  os_disk_storage_type   = "Premium_LRS"
  enable_disk_encryption = true
  key_vault_id           = azurerm_key_vault.disk_encryption.id
  key_vault_name         = azurerm_key_vault.disk_encryption.name

  tags = merge(var.tags, {
    Service = "Jenkins Agent"
    Role    = "CI/CD"
  })

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# SonarQube VM

module "sonarqube_vm" {
  source = "../../modules/compute"

  resource_group_name    = azurerm_resource_group.devsecops.name
  location               = azurerm_resource_group.devsecops.location
  vm_name                = "vm-sonarqube-${var.environment}"
  vm_size                = "Standard_D2s_v3"
  admin_username         = "azureadmin"
  ssh_public_key         = file(var.ssh_public_key_path)
  subnet_id              = module.networking.subnet_ids["subnet-devsecops"]
  nsg_id                 = module.security_web.nsg_id
  create_public_ip       = true
  public_ip_dns_name     = "sonarqube-cptm8net"
  os_disk_size_gb        = 100
  os_disk_storage_type   = "Premium_LRS"
  enable_disk_encryption = true
  key_vault_id           = azurerm_key_vault.disk_encryption.id
  key_vault_name         = azurerm_key_vault.disk_encryption.name

  tags = merge(var.tags, {
    Service = "SonarQube"
    Role    = "SAST"
  })

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

module "artifactory_vm" {
  source = "../../modules/compute"

  resource_group_name    = azurerm_resource_group.devsecops.name
  location               = azurerm_resource_group.devsecops.location
  vm_name                = "vm-sonarqube-${var.environment}"
  vm_size                = "Standard_D2s_v3"
  admin_username         = "azureadmin"
  ssh_public_key         = file(var.ssh_public_key_path)
  subnet_id              = module.networking.subnet_ids["subnet-devsecops"]
  nsg_id                 = module.security_web.nsg_id
  create_public_ip       = true
  public_ip_dns_name     = "artifactory-cptm8net"
  os_disk_size_gb        = 100
  os_disk_storage_type   = "Premium_LRS"
  enable_disk_encryption = true
  key_vault_id           = azurerm_key_vault.disk_encryption.id
  key_vault_name         = azurerm_key_vault.disk_encryption.name

  tags = merge(var.tags, {
    Service = "Artifactory"
    Role    = "SBOM"
  })

  depends_on = [azurerm_key_vault_access_policy.current_user]
}

# PostgreSQL for SonarQube

module "postgresql_sonarqube" {
  source = "../../modules/postgresql_flexible"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  vm_name             = "psql-sonarqube-${var.environment}"
  vnet_id             = module.networking.vnet_id
  subnet_id           = module.networking.subnet_ids["subnet-postgresql"]

  postgresql_admin_username = "sqadmin"
  postgresql_admin_password = var.postgresql_sonarqube_admin_password

  tags = merge(var.tags, {
    Service = "Postgresql-sonarqube"
    Role    = "SAST Data"
  })
}

# PostgreSQL for Artifactory
module "postgresql_artifactory" {
  source = "../../modules/postgresql_flexible"

  resource_group_name = azurerm_resource_group.devsecops.name
  location            = azurerm_resource_group.devsecops.location
  vm_name             = "psql-artifactory-${var.environment}"
  vnet_id             = module.networking.vnet_id
  subnet_id           = module.networking.subnet_ids["subnet-postgresql"]

  postgresql_admin_username = "artifactory"
  postgresql_admin_password = var.postgresql_artifactory_admin_password

  tags = merge(var.tags, {
    Service = "Postgresql-Artifactory"
    Role    = "Artifactory Data"
  })
}
