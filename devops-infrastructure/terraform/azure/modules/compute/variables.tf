variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
  default     = "azureadmin"
}

variable "ssh_public_key" {
  description = "SSH public key for authentication"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to attach the VM to"
  type        = string
}

variable "nsg_id" {
  description = "ID of the Network Security Group"
  type        = string
}

variable "create_public_ip" {
  description = "Whether to create a public IP for the VM"
  type        = bool
  default     = true
}

variable "public_ip_dns_name" {
  description = "DNS name label for the public IP"
  type        = string
  default     = null
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB"
  type        = number
  default     = 50
}

variable "os_disk_storage_type" {
  description = "Storage type for OS disk"
  type        = string
  default     = "Premium_LRS"
}

variable "enable_disk_encryption" {
  description = "Enable Azure Disk Encryption"
  type        = bool
  default     = true
}

variable "key_vault_id" {
  description = "ID of the Key Vault for disk encryption (required if enable_disk_encryption is true)"
  type        = string
  default     = null
}

variable "key_vault_name" {
  description = "Name of the Key Vault for disk encryption (required if enable_disk_encryption is true)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
