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
  description = "Existing Google Cloud project ID."
  type        = string
  default     = "multicloud-capstone"
}

variable "gcp_region" {
  description = "Google Cloud region."
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

variable "vault_addr" {
  description = "HashiCorp Vault cluster URL."
  type        = string
  default     = ""
}

variable "vault_namespace" {
  description = "HashiCorp Vault namespace."
  type        = string
  default     = "admin"
}

variable "route53_zone_id" {
  description = "AWS Route 53 Hosted Zone ID for multi-cloud DNS routing and failover. Leave empty to skip DNS failover resources."
  type        = string
  default     = ""
}

variable "app_domain" {
  description = "Fully qualified domain name (inside the hosted zone) used for DNS failover, e.g. app.example.com. Leave empty to skip DNS failover resources."
  type        = string
  default     = ""
}

variable "azure_storage_account_name" {
  description = "Globally unique Azure DR storage account name (3-24 lowercase letters and numbers)."
  type        = string
  default     = "jilanmcsa2026"
}