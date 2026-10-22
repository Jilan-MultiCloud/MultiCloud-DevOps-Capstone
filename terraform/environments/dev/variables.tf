variable "aws_region" {
  description = "AWS region for capstone resources."
  type        = string
  default     = "us-east-1"
}

variable "azure_location" {
  description = "Azure region for capstone resources."
  type        = string
  default     = "East US"
}

variable "gcp_project_id" {
  description = "Existing Google Cloud project ID. Set TF_VAR_gcp_project_id locally."
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "Google Cloud region for capstone resources."
  type        = string
  default     = "us-central1"
}


variable "bucket_name" {
  description = "Globally unique S3 bucket name for development"
  type        = string
  default     = "jilan-multicloud-capstone-dev-2026-319918321628"
}

variable "gcp_bucket_name" {
  description = "Globally unique Google Cloud Storage bucket name"
  type        = string
}
