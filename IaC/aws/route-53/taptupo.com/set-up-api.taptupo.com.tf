terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Using us-east-1 as it appears to be the region in your script
}

# Variables
variable "api_id" {
  description = "The ID of the API Gateway API"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the API"
  default     = "api.taptupo.com"
  type        = string
}

variable "root_domain" {
  description = "The root domain name"
  default     = "taptupo.com"
  type        = string
}

variable "api_gateway_domain" {
  description = "The API Gateway's domain name"
  default     = "d-e2gh8p1962.execute-api.us-east-1.amazonaws.com"
  type        = string
}

variable "origin" {
  description = "The allowed origin for CORS"
  default     = "https://taptupo.com"
  type        = string
}

# Get the hosted zone ID for the domain
data "aws_route53_zone" "domain_zone" {
  name = var.root_domain
}

# Request a new SSL certificate for the API domain
resource "aws_acm_certificate" "api_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS records for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.domain_zone.zone_id
}

# Certificate validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Create a custom domain name for API Gateway
resource "aws_apigatewayv2_domain_name" "api_domain" {
  domain_name = var.domain_name

  domain_name_configuration {
    certificate_arn = aws_acm_certificate_validation.cert_validation.certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }
}

# Map the API to the custom domain
resource "aws_apigatewayv2_api_mapping" "api_mapping" {
  api_id      = var.api_id
  domain_name = aws_apigatewayv2_domain_name.api_domain.id
  stage       = "prod"
}

# Create Route53 alias record for the API Gateway domain
resource "aws_route53_record" "api_record" {
  zone_id = data.aws_route53_zone.domain_zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api_domain.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}

# Update API Gateway CORS configuration
resource "aws_apigatewayv2_api" "api" {
  api_id = var.api_id

  cors_configuration {
    allow_origins = [var.origin]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
    expose_headers = ["*"]
    max_age = 86400
  }
}

# Outputs
output "certificate_arn" {
  value = aws_acm_certificate.api_cert.arn
}

output "api_domain_url" {
  value = "https://${var.domain_name}"
}

output "validation_status" {
  value = aws_acm_certificate_validation.cert_validation.validation_record_fqdns
}
