# ==============================================================================
# DISASTER RECOVERY STORAGE (SPRINT 4)
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

# ==============================================================================
# AWS LAMBDA (DOCKER-BASED COMPUTE)
# ==============================================================================
# Retrieve the latest image pushed by the CI/CD pipeline
data "aws_ecr_image" "latest" {
  repository_name = aws_ecr_repository.capstone_repo.name
  image_tag       = "latest"
}

resource "aws_iam_role" "lambda_exec" {
  name = "multicloud_capstone_lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "capstone_lambda" {
  function_name = "multicloud-capstone-app"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.capstone_repo.repository_url}:latest"
  timeout       = 15

  environment {
    variables = {
      CLOUD_NAME = "aws"
      PORT       = "8080"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution
  ]
}

# Function URL requires AWS IAM authorization to match your router.py AWS4Auth logic
resource "aws_lambda_function_url" "capstone_url" {
  function_name      = aws_lambda_function.capstone_lambda.function_name
  authorization_type = "AWS_IAM"
}