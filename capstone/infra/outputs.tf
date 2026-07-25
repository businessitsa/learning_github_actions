# infra/outputs.tf
output "app_url" {
  description = "Public URL of the capstone container app"
  value       = "https://${azurerm_container_app.hello.ingress[0].fqdn}"
}

output "storage_account_name" {
  description = "Generated name of the data storage account"
  value       = azurerm_storage_account.data.name
}

output "virtual_network_id" {
  description = "Resource ID of the capstone virtual network"
  value       = azurerm_virtual_network.capstone.id
}
