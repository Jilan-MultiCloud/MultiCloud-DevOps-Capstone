data "archive_file" "aws_lambda_package" {
  type        = "zip"
  source_file = "${path.root}/../../../app/lambda_function.py"
  output_path = "${path.root}/lambda_function.zip"
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
  azure_storage_account_name = "jilanmcsa2026"
}

module "gcp" {
  source = "../../modules/gcp"

  bucket_name      = var.gcp_bucket_name
  gcp_region       = var.gcp_region
  gcp_project_id   = var.gcp_project_id
  cloud_run_region = var.gcp_cloud_run_region
}

# -----------------------------------------------------------------------------
# Sprint 3: Load Balancing & DNS-Based Failover (Route 53 Configuration)
# -----------------------------------------------------------------------------

# Route 53 Health Check to monitor primary AWS endpoint availability
resource "aws_route53_health_check" "primary_health" {
  fqdn              = lookup(module.aws, "alb_dns_name", "placeholder.amazonaws.com")
  port              = 80
  type              = "HTTP"
  resource_path     = "/healthz"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "MultiCloud-Primary-HealthCheck"
  }
}

# Primary Route 53 DNS Record (AWS)
resource "aws_route53_record" "app_primary_aws" {
  zone_id        = var.route53_zone_id
  name           = "app.multicloud-capstone.com"
  type           = "A"
  set_identifier = "AWS-Primary"

  failover_routing_policy {
    type = "PRIMARY"
  }

  health_check_id = aws_route53_health_check.primary_health.id

  alias {
    name                   = lookup(module.aws, "alb_dns_name", "placeholder.amazonaws.com")
    zone_id                = lookup(module.aws, "alb_zone_id", "Z2FDTNDATAQYW2")
    evaluate_target_health = true
  }
}

# Secondary/Failover Route 53 DNS Record (Azure / GCP Fallback)
resource "aws_route53_record" "app_secondary_fallback" {
  zone_id        = var.route53_zone_id
  name           = "app.multicloud-capstone.com"
  type           = "CNAME"
  ttl            = 60
  set_identifier = "Azure-GCP-Secondary"

  failover_routing_policy {
    type = "SECONDARY"
  }

  records = [lookup(module.azure, "lb_dns_name", "fallback.azure.com")]
}

# -----------------------------------------------------------------------------
# Sprint 4: Disaster Recovery & Cross-Cloud Backup Storage
# -----------------------------------------------------------------------------

# AWS Secondary Backup & DR Storage Bucket
resource "aws_s3_bucket" "dr_backup_bucket" {
  bucket        = "multicloud-dr-backups-aws-${var.aws_region}"
  force_destroy = true

  tags = {
    Environment = "DisasterRecovery"
    ManagedBy   = "Terraform"
  }
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