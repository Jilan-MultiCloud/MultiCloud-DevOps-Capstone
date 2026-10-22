
module "aws" {
  source = "../../modules/aws"

  aws_region  = var.aws_region
  bucket_name = var.bucket_name
}

module "azure" {
  source = "../../modules/azure"

  azure_location = var.azure_location
}

module "gcp" {
  source = "../../modules/gcp"

  bucket_name = var.gcp_bucket_name
  gcp_region  = var.gcp_region
}
