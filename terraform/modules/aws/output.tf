output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.capstone.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.capstone.arn
}

output "ecr_repository_url" {
  description = "URL of the AWS ECR Repository"
  value       = aws_ecr_repository.capstone_repo.repository_url
}

output "lambda_function_url" {
  description = "The public URL of the Lambda Function (Secured via IAM)"
  value       = aws_lambda_function_url.capstone_url.function_url
}