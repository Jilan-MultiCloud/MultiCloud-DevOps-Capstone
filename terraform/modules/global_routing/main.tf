terraform {
  required_providers {
    azurerm = { source = "hashicorp/azurerm" }
  }
}

variable "resource_group_name" { type = string }
variable "name" { type = string }
variable "origins" {
  description = "Public HTTPS hostnames; origin host headers preserve provider TLS/routing."
  type        = map(object({ host = string, priority = number, weight = number }))
}

resource "azurerm_cdn_frontdoor_profile" "capstone" {
  name                = var.name
  resource_group_name = var.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = { Project = "MultiCloud-DevOps-Capstone", ManagedBy = "Terraform" }
}

resource "azurerm_cdn_frontdoor_endpoint" "capstone" {
  name                     = var.name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.capstone.id
}

resource "azurerm_cdn_frontdoor_origin_group" "capstone" {
  name                     = "multicloud"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.capstone.id
  session_affinity_enabled = false
  load_balancing {
    sample_size                        = 4
    successful_samples_required        = 3
    additional_latency_in_milliseconds = 100
  }
  health_probe {
    interval_in_seconds = 30
    path                = "/health"
    protocol            = "Https"
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_origin" "cloud" {
  for_each                       = var.origins
  name                           = each.key
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.capstone.id
  enabled                        = true
  host_name                      = each.value.host
  origin_host_header             = each.value.host
  certificate_name_check_enabled = true
  http_port                      = 80
  https_port                     = 443
  priority                       = each.value.priority
  weight                         = each.value.weight
}

resource "azurerm_cdn_frontdoor_route" "capstone" {
  name                          = "application"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.capstone.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.capstone.id
  cdn_frontdoor_origin_ids      = [for origin in azurerm_cdn_frontdoor_origin.cloud : origin.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "HttpsOnly"
  https_redirect_enabled        = true
  link_to_default_domain        = true
  # No cache: health and application responses must come from live origins.
}

output "url" {
  value = "https://${azurerm_cdn_frontdoor_endpoint.capstone.host_name}"
}
