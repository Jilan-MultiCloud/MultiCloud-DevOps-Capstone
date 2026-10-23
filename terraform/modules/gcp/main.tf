
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

resource "google_cloud_run_v2_service" "capstone" {
  name                = "multicloud-capstone"
  location            = var.cloud_run_region
  project             = var.gcp_project_id
  deletion_protection = true

  # Allow unauthenticated requests to the service.
  invoker_iam_disabled = true

  scaling {
    manual_instance_count = 0
    min_instance_count    = 0
  }

  template {
    timeout                          = "30s"
    max_instance_request_concurrency = 80

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "asia-south1-docker.pkg.dev/heroviredacademics/cloud-run-source-deploy/multicloud-capstone@sha256:ff099483af832b978a640e6205fb3c9de234076a2f3896813a1f8807d895ceba"

      ports {
        container_port = 8080
      }

      env {
        name  = "CLOUD_NAME"
        value = "gcp"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "256Mi"
        }

        cpu_idle          = true
        startup_cpu_boost = true
      }

      startup_probe {
        failure_threshold = 1
        period_seconds    = 240
        timeout_seconds   = 240

        tcp_socket {
          port = 8080
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [
      client,
      client_version,
      build_config,
      template[0].annotations["run.googleapis.com/client-name"],
      template[0].annotations["run.googleapis.com/client-version"],
      template[0].annotations["run.googleapis.com/startup-cpu-boost"],
      template[0].labels["client.knative.dev/nonce"],
    ]
  }
}
