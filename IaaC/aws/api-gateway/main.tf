provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

# 1) REST API
resource "aws_api_gateway_rest_api" "exchange_api" {
  name        = "exchange-api"
  description = "Proxy /exchange to Lambda"
}

# 2) /exchange resource
resource "aws_api_gateway_resource" "exchange" {
  rest_api_id = aws_api_gateway_rest_api.exchange_api.id
  parent_id   = aws_api_gateway_rest_api.exchange_api.root_resource_id
  path_part   = "exchange"
}

# 3) POST method, no auth
resource "aws_api_gateway_method" "exchange_post" {
  rest_api_id   = aws_api_gateway_rest_api.exchange_api.id
  resource_id   = aws_api_gateway_resource.exchange.id
  http_method   = "POST"
  authorization = "NONE"
}

# 4) Lambda integration (proxy)
resource "aws_api_gateway_integration" "exchange" {
  rest_api_id = aws_api_gateway_rest_api.exchange_api.id
  resource_id = aws_api_gateway_resource.exchange.id
  http_method = aws_api_gateway_method.exchange_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.exchange_handler.invoke_arn
}

# 5) Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "allow_api" {
  statement_id  = "AllowApiInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.exchange_handler.function_name
  principal     = "apigateway.amazonaws.com"
  # restrict to this API/method/path
  source_arn = "${aws_api_gateway_rest_api.exchange_api.execution_arn}/*/POST/exchange"
}

# 6) Deploy & Stage
resource "aws_api_gateway_deployment" "exchange_deploy" {
  depends_on = [aws_api_gateway_integration.exchange]
  rest_api_id = aws_api_gateway_rest_api.exchange_api.id

  # force new deployment when integration changes
  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_integration.exchange))
  }
}

resource "aws_api_gateway_stage" "prod" {
  stage_name    = var.stage_name
  rest_api_id   = aws_api_gateway_rest_api.exchange_api.id
  deployment_id = aws_api_gateway_deployment.exchange_deploy.id
}

# 7) Bring in your existing Lambda by name
data "aws_lambda_function" "exchange_handler" {
  function_name = var.lambda_function_name
}

output "exchange_url" {
  description = "POST URL for /exchange"
  value       = "${aws_api_gateway_rest_api.exchange_api.execution_invoke_url}/${aws_api_gateway_stage.prod.stage_name}/exchange"
}
