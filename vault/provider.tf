# terraform-infra/provider.tf

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 3.0"
    }
  }

  # Distributed remote state management with backend consistency locking
  backend "s3" {
    bucket         = "multicloud-capstone-tfstate-bucket"
    key            = "global-platform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "multicloud-lock-table"
  }
}

# Connect with local Vault API server
provider "vault" {
  address = var.vault_addr
  token   = var.vault_token
}

# Pull structural credential parameters out of Vault
data "vault_generic_secret" "cloud_credentials" {
  path = "secret/data/multicloud-auth"
}

# Set up Cloud Engine authentications dynamically
provider "aws" {
  region     = var.aws_region
  access_key = data.vault_generic_secret.cloud_credentials.data.data["aws_access_key"]
  secret_key = data.vault_generic_secret.cloud_credentials.data.data["aws_secret_key"]
}

provider "azurerm" {
  features {}
  client_id       = data.vault_generic_secret.cloud_credentials.data.data["azure_client_id"]
  client_secret   = data.vault_generic_secret.cloud_credentials.data.data["azure_client_secret"]
  tenant_id       = data.vault_generic_secret.cloud_credentials.data.data["azure_tenant_id"]
  subscription_id = data.vault_generic_secret.cloud_credentials.data.data["azure_subscription_id"]
}

provider "google" {
  project     = var.gcp_project_id
  region      = var.gcp_region
  credentials = data.vault_generic_secret.cloud_credentials.data.data["gcp_service_account_json"]
}

