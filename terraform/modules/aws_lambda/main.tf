resource "aws_iam_role" "lambda_execution" {
  name = "${var.function_name}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "capstone_api" {
  function_name = var.function_name
  description   = "Minimal API for the multi-cloud Terraform capstone"

  role             = aws_iam_role.lambda_execution.arn
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  filename         = var.lambda_filename
  source_code_hash = var.source_code_hash

  memory_size = 128
  timeout     = 5
  publish     = false

  depends_on = [
    aws_iam_role_policy_attachment.basic_execution
  ]

  tags = {
    Project     = "MultiCloud-DevOps-Capstone"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

resource "aws_lambda_function_url" "capstone_api" {
  function_name      = aws_lambda_function.capstone_api.function_name
  authorization_type = "AWS_IAM"
}
