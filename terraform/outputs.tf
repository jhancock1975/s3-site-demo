output "s3_bucket_name" {
  description = "S3 bucket for static site"
  value       = aws_s3_bucket.site.bucket
}

output "api_endpoint" {
  description = "API Gateway endpoint"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}
