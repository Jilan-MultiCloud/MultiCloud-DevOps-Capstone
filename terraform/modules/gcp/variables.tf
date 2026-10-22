variable "bucket_name" {
  description = "Globally unique Google Cloud Storage bucket name"
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud Storage bucket location"
  type        = string
  default     = "us-central1"
}

variable "gcp_project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "cloud_run_region" {
  description = "Region of the Cloud Run service"
  type        = string
  default     = "asia-south1"
}