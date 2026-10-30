# ==============================================================================
# S3 STORAGE BUCKET
# ==============================================================================
resource "aws_s3_bucket" "capstone" {
  bucket = var.bucket_name
  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "capstone" {
  bucket                  = aws_s3_bucket.capstone.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "capstone" {
  bucket = aws_s3_bucket.capstone.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==============================================================================
# AWS ELASTIC CONTAINER REGISTRY (ECR)
# ==============================================================================
resource "aws_ecr_repository" "capstone_repo" {
  name                 = "multicloud-capstone"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Cost optimisation: keep only the 5 most recent images.
resource "aws_ecr_lifecycle_policy" "capstone_repo" {
  repository = aws_ecr_repository.capstone_repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = {
        type = "expire"
      }
    }]
  })
}
