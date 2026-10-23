
resource "azurerm_resource_group" "capstone" {
  name     = "rg-multicloud-capstone-dev"
  location = var.azure_location

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_container_registry" "capstone" {
  name                = var.azure_acr_name
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_container_app_environment" "capstone" {
  name                = "cae-multicloud-capstone-dev"
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location

  logs_destination = "azure-monitor"

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_user_assigned_identity" "acr_pull" {
  name                = "uai-multicloud-capstone-dev"
  resource_group_name = azurerm_resource_group.capstone.name
  location            = azurerm_resource_group.capstone.location

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.capstone.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.acr_pull.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app" "capstone" {
  name                         = "ca-multicloud-capstone-dev"
  resource_group_name          = azurerm_resource_group.capstone.name
  container_app_environment_id = azurerm_container_app_environment.capstone.id
  revision_mode                = "Single"

  # Explicitly declare the existing Consumption workload profile.
  workload_profile_name = "Consumption"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.acr_pull.id]
  }

  registry {
    server   = azurerm_container_registry.capstone.login_server
    identity = azurerm_user_assigned_identity.acr_pull.id
  }

  ingress {
    external_enabled = true
    target_port      = 8080
    transport        = "auto"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = 0
    max_replicas = 2

    container {
      name   = "multicloud-capstone"
      image  = "${azurerm_container_registry.capstone.login_server}/multicloud-capstone:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "CLOUD_NAME"
        value = "azure"
      }

      env {
        name  = "PORT"
        value = "8080"
      }
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull
  ]

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}
