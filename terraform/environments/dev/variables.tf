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
