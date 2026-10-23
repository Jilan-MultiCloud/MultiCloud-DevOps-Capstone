
output "configured_clouds" {
  description = "Cloud providers declared in this Terraform environment."
  value       = ["aws", "azure", "gcp"]
}

output "aws_bucket_name" {
  description = "Name of the AWS S3 bucket."
  value       = module.aws.bucket_name
}

output "aws_bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = module.aws.bucket_arn
}

output "aws_lambda_function_name" {
  description = "Name of the Lambda function in Mumbai."
  value       = module.aws_lambda.function_name
}

output "aws_lambda_function_arn" {
  description = "ARN of the Lambda function in Mumbai."
  value       = module.aws_lambda.function_arn
}

output "aws_lambda_function_url" {
  description = "IAM-authenticated AWS Lambda Function URL."
  value       = module.aws_lambda.function_url
}

output "azure_resource_group_name" {
  description = "Name of the Azure resource group."
  value       = module.azure.resource_group_name
}

output "azure_resource_group_location" {
  description = "Location of the Azure resource group."
  value       = module.azure.resource_group_location
}

output "azure_container_registry_name" {
  description = "Name of the Azure Container Registry."
  value       = module.azure.container_registry_name
}

output "azure_container_registry_login_server" {
  description = "Login server for the Azure Container Registry."
  value       = module.azure.container_registry_login_server
}

output "azure_container_app_environment_name" {
  description = "Name of the Azure Container Apps environment."
  value       = module.azure.container_app_environment_name
}

output "azure_container_app_environment_id" {
  description = "Resource ID of the Azure Container Apps environment."
  value       = module.azure.container_app_environment_id
}

output "azure_container_app_name" {
  description = "Name of the Azure Container App."
  value       = module.azure.container_app_name
}

output "azure_container_app_url" {
  description = "Public HTTPS URL of the Azure Container App."
  value       = module.azure.container_app_url
}

output "azure_container_app_identity_id" {
  description = "Resource ID of the managed identity used to pull the image."
  value       = module.azure.container_app_identity_id
}

output "gcp_bucket_name" {
  description = "Name of the Google Cloud Storage bucket."
  value       = module.gcp.bucket_name
}

output "gcp_bucket_url" {
  description = "Google Cloud Storage bucket URL."
  value       = module.gcp.bucket_url
}

output "gcp_cloud_run_service_name" {
  description = "Name of the existing Google Cloud Run service."
  value       = module.gcp.cloud_run_service_name
}

output "gcp_cloud_run_service_url" {
  description = "URL of the existing Google Cloud Run service."
  value       = module.gcp.cloud_run_service_url
}
