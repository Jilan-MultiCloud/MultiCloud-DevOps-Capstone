variable "azure_location" {
  description = "Azure region for the capstone resources."
  type        = string
  default     = "East US"
}

variable "azure_acr_name" {
  description = "Globally unique Azure Container Registry name."
  type        = string
}

variable "azure_storage_account_name" {
  description = "Globally unique name for the Azure DR Storage Account (must be lowercase and numbers only)."
  type        = string
}