terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "lambda_role_name" {
  description = "Name of the IAM role for Lambda execution"
  type        = string
  default     = "your-lambda-exec-role"
}

variable "domain_name" {
  description = "Custom API domain"
  type        = string
  default     = "api.taptupo.com"
}

variable "stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "prod"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "europeana-lambda"
}

variable "lambda_source_path" {
  description = "Path to the Lambda bootstrap ZIP file"
  type        = string
  default     = "./lambda/europeana_handler/function.zip"
}

data "aws_acm_certificate" "cert" {
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

resource "aws_iam_role" "lambda_exec_role" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_lambda_function" "europeana" {
  function_name = var.lambda_function_name
  filename      = var.lambda_source_path
  handler       = "bootstrap"
  runtime       = "provided.al2"
  role          = aws_iam_role.lambda_exec_role.arn
  architectures = ["x86_64"]

  source_code_hash = filebase64sha256(var.lambda_source_path)
}

resource "aws_lambda_permission" "api_gw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.europeana.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:*/*/*"
}

resource "aws_apigatewayv2_api" "europeana_api" {
  name          = var.lambda_function_name
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_proxy" {
  api_id                 = aws_apigatewayv2_api.europeana_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.europeana.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "search_route" {
  api_id    = aws_apigatewayv2_api.europeana_api.id
  route_key = "GET /search"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.europeana_api.id
  name        = var.stage_name
  auto_deploy = true

  depends_on = [aws_apigatewayv2_route.search_route]
}

resource "aws_apigatewayv2_domain_name" "custom" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = data.aws_acm_certificate.cert.arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

resource "aws_apigatewayv2_api_mapping" "mapping" {
  api_id          = aws_apigatewayv2_api.europeana_api.id
  domain_name     = aws_apigatewayv2_domain_name.custom.domain_name
  stage           = aws_apigatewayv2_stage.prod.name
  api_mapping_key = "search"
}

data "aws_region" "current" {}
