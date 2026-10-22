resource "google_storage_bucket" "capstone" {
  name                        = var.bucket_name
  location                    = var.gcp_region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false
  }

  labels = {
    project     = "multicloud-devops-capstone"
    environment = "dev"
    managed_by  = "terraform"
  }
}
