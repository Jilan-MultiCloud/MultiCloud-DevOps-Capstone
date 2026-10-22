variable "bucket_name" {
  description = "Globally unique Google Cloud Storage bucket name"
  type        = string
}

variable "gcp_region" {
  description = "Google Cloud Storage bucket location"
  type        = string
  default     = "us-central1"
}
