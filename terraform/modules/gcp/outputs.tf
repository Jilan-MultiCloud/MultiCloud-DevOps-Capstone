output "bucket_name" {
  description = "Name of the Google Cloud Storage bucket"
  value       = google_storage_bucket.capstone.name
}

output "bucket_url" {
  description = "Google Cloud Storage bucket URL"
  value       = "gs://${google_storage_bucket.capstone.name}"
}
