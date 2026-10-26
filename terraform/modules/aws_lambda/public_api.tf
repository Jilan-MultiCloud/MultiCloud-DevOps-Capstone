variable "enable_public_api" {
  description = "Explicit opt-in for a public read-only demo API used by global routing. Function URL stays IAM protected."
  type        = bool
  default     = false
}

resource "aws_apigatewayv2_api" "public" {
  count         = var.enable_public_api ? 1 : 0
  name          = "${var.function_name}-global"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "public" {
  count                  = var.enable_public_api ? 1 : 0
  api_id                 = aws_apigatewayv2_api.public[0].id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.capstone_api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "public" {
  for_each  = var.enable_public_api ? toset(["GET /", "GET /health"]) : toset([])
  api_id    = aws_apigatewayv2_api.public[0].id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.public[0].id}"
}

resource "aws_apigatewayv2_stage" "public" {
  count       = var.enable_public_api ? 1 : 0
  api_id      = aws_apigatewayv2_api.public[0].id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_burst_limit = 20
    throttling_rate_limit  = 10
  }
}

resource "aws_lambda_permission" "public_api" {
  count         = var.enable_public_api ? 1 : 0
  statement_id  = "AllowCapstoneAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.capstone_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.public[0].execution_arn}/*/GET/*"
}

output "public_api_url" {
  value = try(aws_apigatewayv2_api.public[0].api_endpoint, null)
}
