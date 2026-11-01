data "archive_file" "aws_lambda_package" {
  type        = "zip"
  source_file = "${path.root}/../../../app/lambda_function.py"
  output_path = "${path.root}/lambda_function.zip"
}

locals {
  # DNS failover is only created when a hosted zone and domain are supplied,
  # so `terraform plan` works for everyone without a registered domain.
  enable_dns = var.route53_zone_id != "" && var.app_domain != ""

  # Cloud endpoints without the https:// prefix (Route 53 wants a bare hostname).
  primary_host   = replace(module.gcp.cloud_run_service_url, "https://", "")
  secondary_host = replace(module.azure.container_app_url, "https://", "")
}

# -----------------------------------------------------------------------------
# Core Cloud Provider Modules (AWS, Azure, GCP)
# -----------------------------------------------------------------------------

module "aws" {
  source = "../../modules/aws"

  aws_region  = var.aws_region
  bucket_name = var.bucket_name
}

module "aws_lambda" {
  source = "../../modules/aws_lambda"

  providers = {
    aws = aws.mumbai
  }

  function_name    = "multicloud-capstone-api"
  lambda_filename  = data.archive_file.aws_lambda_package.output_path
  source_code_hash = data.archive_file.aws_lambda_package.output_base64sha256
}

module "azure" {
  source = "../../modules/azure"

  azure_location             = var.azure_location
  azure_acr_name             = var.azure_acr_name
  azure_storage_account_name = var.azure_storage_account_name
}

module "gcp" {
  source = "../../modules/gcp"

  bucket_name      = var.gcp_bucket_name
  gcp_region       = var.gcp_region
  gcp_project_id   = var.gcp_project_id
  cloud_run_region = var.gcp_cloud_run_region
}

# -----------------------------------------------------------------------------
# Sprint 3: DNS-Based Failover (Route 53)
#
# Primary   = GCP Cloud Run   (public endpoint)
# Secondary = Azure Container Apps (public endpoint)
#
# The AWS Lambda Function URL uses AWS_IAM auth, so Route 53 health checkers
# (which cannot sign requests) cannot probe it; it stays reachable through the
# signed requests made by app/router.py instead.
# -----------------------------------------------------------------------------

resource "aws_route53_health_check" "primary" {
  count = local.enable_dns ? 1 : 0

  fqdn              = local.primary_host
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  enable_sni        = true

  tags = {
    Name = "MultiCloud-Primary-GCP-HealthCheck"
  }
}

resource "aws_route53_health_check" "secondary" {
  count = local.enable_dns ? 1 : 0

  fqdn              = local.secondary_host
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
  enable_sni        = true

  tags = {
    Name = "MultiCloud-Secondary-Azure-HealthCheck"
  }
}

resource "aws_route53_record" "app_primary" {
  count = local.enable_dns ? 1 : 0

  zone_id        = var.route53_zone_id
  name           = var.app_domain
  type           = "CNAME"
  ttl            = 60
  set_identifier = "GCP-Primary"
  records        = [local.primary_host]

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary[0].id
}

resource "aws_route53_record" "app_secondary" {
  count = local.enable_dns ? 1 : 0

  zone_id        = var.route53_zone_id
  name           = var.app_domain
  type           = "CNAME"
  ttl            = 60
  set_identifier = "Azure-Secondary"
  records        = [local.secondary_host]

  failover_routing_policy {
    type = "SECONDARY"
  }

  health_check_id = aws_route53_health_check.secondary[0].id
}

# -----------------------------------------------------------------------------
# Sprint 4: Disaster Recovery & Cross-Cloud Backup Storage
#
# Replica targets in every cloud:
#   AWS   -> this bucket (versioned, encrypted, private)
#   Azure -> module.azure storage account / dr-backups container
#   GCP   -> module.gcp bucket (dr-replicas/ prefix)
# scripts/dr_backup_sync.py copies backups between them and runs the restore drill.
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "dr_backup_bucket" {
  bucket        = "multicloud-dr-backups-aws-${var.aws_region}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Environment = "DisasterRecovery"
    ManagedBy   = "Terraform"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket_public_access_block" "dr_backup_bucket" {
  bucket                  = aws_s3_bucket.dr_backup_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "dr_versioning" {
  bucket = aws_s3_bucket.dr_backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dr_encryption" {
  bucket = aws_s3_bucket.dr_backup_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Cost optimisation: expire old backup versions so storage cost stays bounded.
resource "aws_s3_bucket_lifecycle_configuration" "dr_lifecycle" {
  bucket = aws_s3_bucket.dr_backup_bucket.id

  rule {
    id     = "expire-old-backups"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
