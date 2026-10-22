resource "azurerm_resource_group" "capstone" {
  name     = "rg-multicloud-capstone-dev"
  location = var.azure_location

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
