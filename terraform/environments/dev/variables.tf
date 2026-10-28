variable "aws_region" {
  description = "AWS region for capstone resources."
  type        = string
  default     = "ap-south-1"
}

variable "azure_location" {
  description = "Azure region for capstone resources."
  type        = string
  default     = "centralindia"
}

variable "gcp_project_id" {
  description = "Existing Google Cloud project ID. Set TF_VAR_gcp_project_id locally."
  type        = string
  default     = "multicloud-capstone"
}

variable "gcp_region" {
  description = "Google Cloud Storage bucket location."
  type        = string
  default     = "asia-south1"
}

variable "gcp_cloud_run_region" {
  description = "Region of the existing Google Cloud Run service."
  type        = string
  default     = "asia-south1"
}

variable "bucket_name" {
  description = "Globally unique S3 bucket name for development."
  type        = string
  default     = "jilan-multicloud-capstone-dev-2026-319918321628"
}

variable "gcp_bucket_name" {
  description = "Globally unique Google Cloud Storage bucket name."
  type        = string
  default     = "multicloud-capstone-storage-jilan-2026"
}

variable "azure_acr_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
  default     = "jilanmccapstone2026"
}