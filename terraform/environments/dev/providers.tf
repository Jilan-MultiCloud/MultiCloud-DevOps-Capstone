# ==============================================================================
# SECURE CREDENTIAL ARTIFACT RETRIEVAL VIA HASHICORP VAULT
# ==============================================================================
provider "vault" {
  address   = var.vault_addr
  namespace = var.vault_namespace
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
  access_key = data.vault_generic_secret.aws_secrets.data["access_key_id"]
  secret_key = data.vault_generic_secret.aws_secrets.data["secret_access_key"]

  default_tags {
    tags = {
      Environment = "Development"
      Project     = "MultiCloud-DevOps-Capstone"
      ManagedBy   = "Terraform"
      Owner       = "Jilan-MultiCloud"
    }
  }
}

# Aliased AWS provider for Lambda module
provider "aws" {
  alias      = "mumbai"
  region     = var.aws_region
  access_key = data.vault_generic_secret.aws_secrets.data["access_key_id"]
  secret_key = data.vault_generic_secret.aws_secrets.data["secret_access_key"]

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
  project = var.gcp_project_id
  region  = var.gcp_region

  credentials = jsonencode({
    type                        = data.vault_generic_secret.gcp_secrets.data["type"]
    project_id                  = data.vault_generic_secret.gcp_secrets.data["project_id"]
    private_key_id              = data.vault_generic_secret.gcp_secrets.data["private_key_id"]
    private_key                 = data.vault_generic_secret.gcp_secrets.data["private_key"]
    client_email                = data.vault_generic_secret.gcp_secrets.data["client_email"]
    client_id                   = data.vault_generic_secret.gcp_secrets.data["client_id"]
    auth_uri                    = data.vault_generic_secret.gcp_secrets.data["auth_uri"]
    token_uri                   = data.vault_generic_secret.gcp_secrets.data["token_uri"]
    auth_provider_x509_cert_url = data.vault_generic_secret.gcp_secrets.data["auth_provider_x509_cert_url"]
    client_x509_cert_url        = data.vault_generic_secret.gcp_secrets.data["client_x509_cert_url"]
    universe_domain             = data.vault_generic_secret.gcp_secrets.data["universe_domain"]
  })
}