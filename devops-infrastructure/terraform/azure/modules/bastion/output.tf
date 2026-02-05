output "bastion_id" {
  description = "The ID of the Bastion Host"
  value       = azurerm_bastion_host.bastion.id
}

output "bastion_dns_name" {
  description = "The DNS name of the Bastion Host"
  value       = azurerm_bastion_host.bastion.dns_name
}

output "public_ip_address" {
  description = "The public IP address of the Bastion"
  value       = azurerm_public_ip.bastion.ip_address
}
