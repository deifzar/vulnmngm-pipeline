output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.devsecops.name
}

output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.networking.vnet_id
}

output "bastion_fqdn" {
  description = "FQDN of the Bastion host"
  value       = var.enable_bastion ? module.bastion[0].bastion_dns_name : null
}

output "jenkins_vm_details" {
  description = "Jenkins VM connection details"
  value = {
    vm_name    = module.jenkins_vm.vm_name
    private_ip = module.jenkins_vm.private_ip_address
    public_ip  = module.jenkins_vm.public_ip_address
    fqdn       = module.jenkins_vm.public_ip_fqdn
  }
}

# SonarQube VM details
output "sonarqube_vm_details" {
  description = "SonarQube VM connection details"
  value = {
    vm_name    = module.sonarqube_vm.vm_name
    private_ip = module.sonarqube_vm.private_ip_address
    public_ip  = module.sonarqube_vm.public_ip_address
    fqdn       = module.sonarqube_vm.public_ip_fqdn
  }
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.disk_encryption.name
}

# Export for Ansible dynamic inventory
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    jenkins = {
      ansible_host = module.jenkins_vm.public_ip_address
      ansible_user = "azureadmin"
      private_ip   = module.jenkins_vm.private_ip_address
    }
    sonarqube = {
      ansible_host = module.sonarqube_vm.public_ip_address
      ansible_user = "azureadmin"
      private_ip   = module.sonarqube_vm.private_ip_address
    }
  }
}
