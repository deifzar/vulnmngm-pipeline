# Public IP (conditional)
resource "azurerm_public_ip" "vm" {
  count = var.create_public_ip ? 1 : 0

  name                = "pip-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = var.public_ip_dns_name

  tags = var.tags
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.create_public_ip ? azurerm_public_ip.vm[0].id : null
  }

  tags = var.tags
}

# Associate NSG with Network Interface
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = var.nsg_id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.vm.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_type
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # Disable password authentication
  disable_password_authentication = true

  tags = var.tags
}

# Azure Disk Encryption (conditional)
resource "azurerm_virtual_machine_extension" "disk_encryption" {
  count = var.enable_disk_encryption ? 1 : 0

  name                       = "AzureDiskEncryption"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Security"
  type                       = "AzureDiskEncryptionForLinux"
  type_handler_version       = "1.1"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    EncryptionOperation    = "EnableEncryption"
    KeyVaultURL            = var.key_vault_id != null ? data.azurerm_key_vault.vault[0].vault_uri : null
    KeyVaultResourceId     = var.key_vault_id
    VolumeType             = "All"
    KeyEncryptionAlgorithm = "RSA-OAEP"
  })

  depends_on = [azurerm_linux_virtual_machine.vm]
}

# Data source for Key Vault (if encryption is enabled)
data "azurerm_key_vault" "vault" {
  count = var.enable_disk_encryption ? 1 : 0

  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}
