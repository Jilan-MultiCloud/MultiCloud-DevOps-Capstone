# ==============================================================================
# SECURE CREDENTIAL ARTIFACT RETRIEVAL VIA HASHICORP VAULT
# ==============================================================================
provider "vault" {
  address = "http://127.0.0.1:8200"
  # VAULT_TOKEN environment variable will automatically handle authentication
}

data "vault_generic_secret" "aws_secrets" {
  path = "secret/data/dev/aws"
}

data "vault_generic_secret" "azure_secrets" {
  path = "secret/data/dev/azure"
}

data "vault_generic_secret" "gcp_secrets" {
  path = "secret/data/dev/gcp"
}

# ==============================================================================
# AMAZON WEB SERVICES (AWS) LAYER INITIALIZATION
# ==============================================================================
provider "aws" {
  region     = var.aws_region
  access_key = data.vault_generic_secret.aws_secrets.data["access_key"]
  secret_key = data.vault_generic_secret.aws_secrets.data["secret_key"]

  default_tags {
    tags = {
      Environment = "Development"
      Project     = "MultiCloud-DevOps-Capstone"
      ManagedBy   = "Terraform"
      Owner       = "Jilan-MultiCloud"
    }
  }
}

# ==============================================================================
# MICROSOFT AZURE CLOUD LAYER INITIALIZATION
# ==============================================================================
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    virtual_machine {
      delete_os_disk_on_deletion = true
    }
  }

  subscription_id = data.vault_generic_secret.azure_secrets.data["subscription_id"]
  client_id       = data.vault_generic_secret.azure_secrets.data["client_id"]
  client_secret   = data.vault_generic_secret.azure_secrets.data["client_secret"]
  tenant_id       = data.vault_generic_secret.azure_secrets.data["tenant_id"]
}

# ==============================================================================
# GOOGLE CLOUD PLATFORM (GCP) LAYER INITIALIZATION
# ==============================================================================
provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = data.vault_generic_secret.gcp_secrets.data["service_account_key_json"]
}