
resource "aws_s3_bucket" "capstone" {
  bucket = var.bucket_name

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "capstone" {
  bucket = aws_s3_bucket.capstone.id

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
