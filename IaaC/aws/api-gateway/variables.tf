variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-1"
}

variable "stage_name" {
  type        = string
  description = "API Gateway stage"
  default     = "prod"
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the existing exchangeHandler Lambda"
}
