variable "s3_bucket_name" {
  description = "The name of the S3 bucket to host static files"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "domain" {
  description = "The domain to configure via Cloudflare"
  type        = string
}
