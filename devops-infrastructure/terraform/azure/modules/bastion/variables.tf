variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "bastion_name" {
  description = "Name of the Azure Bastion"
  type        = string
}

variable "bastion_subnet_id" {
  description = "ID of the AzureBastionSubnet"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the public IP for Bastion"
  type        = string
}

variable "sku" {
  description = "SKU of the Bastion (Basic or Standard)"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard"], var.sku)
    error_message = "SKU must be either Basic or Standard"
  }
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
