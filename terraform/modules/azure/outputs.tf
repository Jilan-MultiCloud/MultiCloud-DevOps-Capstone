output "resource_group_name" {
  description = "Name of the Azure resource group"
  value       = azurerm_resource_group.capstone.name
}

output "resource_group_location" {
  description = "Location of the Azure resource group"
  value       = azurerm_resource_group.capstone.location
}
