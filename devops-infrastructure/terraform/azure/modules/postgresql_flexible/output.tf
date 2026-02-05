# PostgreSQL details
output "postgresql_details" {
  description = "PostgreSQL server connection details"
  value = {
    server_name = azurerm_postgresql_flexible_server.sonarqube.name
    fqdn        = azurerm_postgresql_flexible_server.sonarqube.fqdn
    database    = azurerm_postgresql_flexible_server_database.sonarqube.name
    admin_user  = var.postgresql_admin_username
  }
  sensitive = true
}
