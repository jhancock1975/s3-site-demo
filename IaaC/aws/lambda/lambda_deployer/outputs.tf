#################
# (5) Outputs   #
#################
output "invoke_url" {
  description = "Default execute-api URL"
  value       = "https://${aws_api_gateway_rest_api.api.id}.execute-api.${var.aws_region}.amazonaws.com/${var.api_stage_name}/${var.api_resource_path}"
}

output "custom_domain_invoke_url" {
  description = "Invoke via custom domain"
  value       = "https://${var.custom_domain_name}/${var.api_stage_name}/${var.api_resource_path}"
}
