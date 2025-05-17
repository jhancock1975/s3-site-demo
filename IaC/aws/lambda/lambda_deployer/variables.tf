// variables.tf
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler (e.g. index.handler)"
  type        = string
}

variable "lambda_runtime" {
  description = "Lambda runtime (e.g. nodejs14.x, python3.9)"
  type        = string
}

variable "lambda_role_arn" {
  description = "ARN of the IAM role for Lambda execution"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the zipped Lambda deployment package"
  type        =   string
}

variable "api_name" {
  description = "Name for the API Gateway"
  type        = string
}

variable "api_stage_name" {
  description = "Name of the deployment stage"
  type        = string
}

variable "api_resource_path" {
  description = "Path segment under the root" 
  type        = string
}


// variables.tf

variable "custom_domain_name" {
  description = "The fully-qualified custom domain for API Gateway (e.g. api.taptupo.com)"
  type        = string
}

variable "hosted_zone_name" {
  description = "The Route53 hosted zone name (e.g. taptupo.com)"
  type        = string
}
