output "configured_clouds" {
  description = "Cloud providers declared in this Terraform environment. This does not confirm authentication or deploy resources."
  value       = ["aws", "azure", "gcp"]
}
