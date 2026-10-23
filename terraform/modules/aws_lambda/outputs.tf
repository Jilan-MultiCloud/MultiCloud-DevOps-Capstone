output "function_name" {
  description = "Name of the deployed Lambda function."
  value       = aws_lambda_function.capstone_api.function_name
}

output "function_arn" {
  description = "ARN of the deployed Lambda function."
  value       = aws_lambda_function.capstone_api.arn
}

output "function_url" {
  description = "IAM-authenticated Function URL."
  value       = aws_lambda_function_url.capstone_api.function_url
}
