terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# IAM Role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Basic Lambda execution policy attachment
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda function
resource "aws_lambda_function" "cat_facts_lambda" {
  function_name = "cat-facts-lambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "bootstrap"
  runtime       = "provided.al2023"
  architectures = ["x86_64"]
  
  filename      = "lambda_function.zip"  # You'll need to create this zip file with your Lambda code
  
  timeout       = 3
  memory_size   = 128
  
  # Note: In a real environment, use source_code_hash to trigger updates when the code changes
  # source_code_hash = filebase64sha256("lambda_function.zip")
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "cat_facts_api" {
  name          = "cat-facts-api"
  protocol_type = "HTTP"
  
  route_selection_expression = "$request.method $request.path"
  disable_execute_api_endpoint = false
  
  # If you need CORS configuration, uncomment and adjust as needed
  # cors_configuration {
  #   allow_origins = ["*"]
  #   allow_methods = ["GET"]
  #   allow_headers = ["content-type"]
  # }
}

# API Gateway Integration with Lambda
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.cat_facts_api.id
  integration_type = "AWS_PROXY"
  
  integration_uri  = aws_lambda_function.cat_facts_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds = 30000
}

# API Gateway Route
resource "aws_apigatewayv2_route" "catfact_route" {
  api_id    = aws_apigatewayv2_api.cat_facts_api.id
  route_key = "GET /catfact"
  
  target = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.cat_facts_api.id
  name        = "prod"
  auto_deploy = true
}

# Lambda permission to allow API Gateway to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cat_facts_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  
  # The source ARN for the API Gateway
  source_arn = "${aws_apigatewayv2_api.cat_facts_api.execution_arn}/*/*"
}

# Outputs
output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.prod.invoke_url}/catfact"
  description = "The URL to invoke the cat facts API"
}

output "lambda_function_name" {
  value = aws_lambda_function.cat_facts_lambda.function_name
  description = "The name of the Lambda function"
}