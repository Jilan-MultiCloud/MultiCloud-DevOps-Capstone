variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "lambda_filename" {
  description = "Path to the packaged Lambda ZIP file."
  type        = string
}

variable "source_code_hash" {
  description = "Base64-encoded SHA-256 hash of the Lambda ZIP package."
  type        = string
}
