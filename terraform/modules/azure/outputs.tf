
output "resource_group_name" {
  description = "Name of the Azure resource group."
  value       = azurerm_resource_group.capstone.name
}

output "resource_group_location" {
  description = "Location of the Azure resource group."
  value       = azurerm_resource_group.capstone.location
}

output "container_registry_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.capstone.name
}

output "container_registry_login_server" {
  description = "Login server for the Azure Container Registry."
  value       = azurerm_container_registry.capstone.login_server
}

output "container_app_environment_name" {
  description = "Name of the Azure Container Apps environment."
  value       = azurerm_container_app_environment.capstone.name
}

output "container_app_environment_id" {
  description = "Resource ID of the Azure Container Apps environment."
  value       = azurerm_container_app_environment.capstone.id
}

output "container_app_name" {
  description = "Name of the Azure Container App."
  value       = azurerm_container_app.capstone.name
}

output "container_app_url" {
  description = "Public HTTPS URL of the Azure Container App."
  value       = "https://${azurerm_container_app.capstone.ingress[0].fqdn}"
}

output "container_app_identity_id" {
  description = "Resource ID of the managed identity used to pull the image."
  value       = azurerm_user_assigned_identity.acr_pull.id
}
