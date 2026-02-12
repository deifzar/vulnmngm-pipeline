# PostgreSQL details
output "postgresql_details" {
  description = "PostgreSQL server connection details"
  value = {
    server_name = azurerm_postgresql_flexible_server.dbserver.name
    fqdn        = azurerm_postgresql_flexible_server.dbserver.fqdn
    database    = azurerm_postgresql_flexible_server_database.app_database.name
    admin_user  = var.postgresql_admin_username
  }
  sensitive = true
}
