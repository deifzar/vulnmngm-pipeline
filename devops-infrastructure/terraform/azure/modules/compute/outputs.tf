output "vm_id" {
  description = "The ID of the Virtual Machine"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "The name of the Virtual Machine"
  value       = azurerm_linux_virtual_machine.vm.name
}

output "private_ip_address" {
  description = "The private IP address of the VM"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "public_ip_address" {
  description = "The public IP address of the VM (if created)"
  value       = var.create_public_ip ? azurerm_public_ip.vm[0].ip_address : null
}

output "public_ip_fqdn" {
  description = "The FQDN of the public IP (if created)"
  value       = var.create_public_ip ? azurerm_public_ip.vm[0].fqdn : null
}
