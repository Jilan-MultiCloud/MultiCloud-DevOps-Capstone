
output "bucket_name" {
  description = "Name of the Google Cloud Storage bucket"
  value       = google_storage_bucket.capstone.name
}

output "bucket_url" {
  description = "Google Cloud Storage bucket URL"
  value       = "gs://${google_storage_bucket.capstone.name}"
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.capstone.name
}

output "cloud_run_service_url" {
  description = "URL of the Cloud Run service"
  value       = google_cloud_run_v2_service.capstone.uri
}
