provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "mumbai"
  region = "ap-south-1"
}

provider "azurerm" {
  features {}
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
