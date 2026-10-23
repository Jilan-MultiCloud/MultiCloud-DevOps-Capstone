
data "archive_file" "aws_lambda_package" {
  type        = "zip"
  source_file = "${path.root}/../../../app/lambda_function.py"
  output_path = "${path.root}/lambda_function.zip"
}

module "aws" {
  source = "../../modules/aws"

  aws_region  = var.aws_region
  bucket_name = var.bucket_name
}

module "aws_lambda" {
  source = "../../modules/aws_lambda"

  providers = {
    aws = aws.mumbai
  }

  function_name    = "multicloud-capstone-api"
  lambda_filename  = data.archive_file.aws_lambda_package.output_path
  source_code_hash = data.archive_file.aws_lambda_package.output_base64sha256
}

module "azure" {
  source = "../../modules/azure"

  azure_location = var.azure_location
  azure_acr_name = var.azure_acr_name
}

module "gcp" {
  source = "../../modules/gcp"

  bucket_name      = var.gcp_bucket_name
  gcp_region       = var.gcp_region
  gcp_project_id   = var.gcp_project_id
  cloud_run_region = var.gcp_cloud_run_region
}
