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
