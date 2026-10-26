variable "enable_global_routing" {
  description = "Adds paid Front Door and a public AWS GET API. Review cost and exposure before enabling."
  type        = bool
  default     = false
}

variable "global_routing_name" {
  description = "Globally unique Front Door endpoint/profile name."
  type        = string
  default     = "multicloud-capstone-global"
}

variable "azure_image" {
  description = "Immutable ACR image reference; null preserves the existing demo image."
  type        = string
  default     = null
}

variable "gcp_image" {
  description = "Immutable Artifact Registry image reference; null preserves the current deployed image."
  type        = string
  default     = null
}

module "global_routing" {
  count               = var.enable_global_routing ? 1 : 0
  source              = "../../modules/global_routing"
  resource_group_name = module.azure.resource_group_name
  name                = var.global_routing_name
  origins = {
    aws = {
      host     = trimprefix(coalesce(module.aws_lambda.public_api_url, "https://disabled.invalid"), "https://")
      priority = 1
      weight   = 1000
    }
    azure = {
      host     = trimprefix(module.azure.container_app_url, "https://")
      priority = 1
      weight   = 1000
    }
    gcp = {
      host     = trimprefix(module.gcp.cloud_run_service_url, "https://")
      priority = 1
      weight   = 1000
    }
  }
}

output "global_application_url" {
  value = try(module.global_routing[0].url, null)
}

variable "enable_backup_storage" {
  type        = bool
  default     = false
  description = "Adds a private Azure backup account; existing S3/GCS buckets are used for the other replicas."
}

variable "azure_backup_account_name" {
  type        = string
  default     = ""
  description = "Globally unique lowercase alphanumeric Azure account name (3-24 chars)."
  validation {
    condition     = var.azure_backup_account_name == "" || can(regex("^[a-z0-9]{3,24}$", var.azure_backup_account_name))
    error_message = "Use 3-24 lowercase letters/numbers."
  }
}

resource "azurerm_storage_account" "backup" {
  count                           = var.enable_backup_storage ? 1 : 0
  name                            = var.azure_backup_account_name
  resource_group_name             = module.azure.resource_group_name
  location                        = var.azure_location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
  lifecycle {
    precondition {
      condition     = var.azure_backup_account_name != ""
      error_message = "Set azure_backup_account_name before enabling backup storage."
    }
  }
}

resource "azurerm_storage_container" "backup" {
  count                 = var.enable_backup_storage ? 1 : 0
  name                  = "backups"
  storage_account_id    = azurerm_storage_account.backup[0].id
  container_access_type = "private"
}

output "backup_azure_account_url" {
  value = try(azurerm_storage_account.backup[0].primary_blob_endpoint, null)
}
