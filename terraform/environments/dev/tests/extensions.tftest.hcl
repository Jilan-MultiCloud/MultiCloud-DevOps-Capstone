mock_provider "aws" {}
mock_provider "aws" { alias = "mumbai" }
mock_provider "azurerm" {}
mock_provider "google" {
  mock_resource "google_cloud_run_v2_service" {
    defaults = { uri = "https://example.a.run.app" }
  }
}
mock_provider "archive" {}
variables {
  gcp_project_id  = "capstone-test"
  gcp_bucket_name = "capstone-test-bucket"
}
run "extensions_off_by_default" {
  command = plan
  assert {
    condition     = length(module.global_routing) == 0 && length(azurerm_storage_account.backup) == 0
    error_message = "Paid/public extensions must be disabled by default."
  }
}
run "extensions_enabled" {
  command = plan
  variables {
    enable_global_routing     = true
    enable_backup_storage     = true
    azure_backup_account_name = "capstonetestbackup123"
  }
  assert {
    condition     = length(module.global_routing) == 1 && length(azurerm_storage_account.backup) == 1
    error_message = "Optional modules should be included when enabled."
  }
}
