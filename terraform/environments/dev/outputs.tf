output "configured_clouds" {
  description = "Cloud providers declared in this Terraform environment."
  value       = ["aws", "azure", "gcp"]
}

output "aws_bucket_name" {
  description = "Name of the AWS S3 bucket"
  value       = module.aws.bucket_name
}

output "aws_bucket_arn" {
  description = "ARN of the AWS S3 bucket"
  value       = module.aws.bucket_arn
}

output "aws_lambda_function_name" {
  description = "Name of the AWS Lambda function in Mumbai"
  value       = module.aws_lambda.function_name
}

output "aws_lambda_function_arn" {
  description = "ARN of the AWS Lambda function in Mumbai"
  value       = module.aws_lambda.function_arn
}

output "aws_lambda_function_url" {
  description = "IAM-authenticated AWS Lambda Function URL"
  value       = module.aws_lambda.function_url
}

output "azure_resource_group_name" {
  description = "Name of the resource group"
  value       = module.azure.resource_group_name
}

output "azure_resource_group_location" {
  description = "Location of the resource group"
  value       = module.azure.resource_group_location
}

output "gcp_bucket_name" {
  description = "Name of the Google Cloud Storage bucket"
  value       = module.gcp.bucket_name
}

output "gcp_bucket_url" {
  description = "Google Cloud Storage bucket URL"
  value       = module.gcp.bucket_url
}

output "gcp_cloud_run_service_name" {
  description = "Name of the Google Cloud Run service"
  value       = module.gcp.cloud_run_service_name
}

output "gcp_cloud_run_service_url" {
  description = "URL of the Google Cloud Run service"
  value       = module.gcp.cloud_run_service_url
}
