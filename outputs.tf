output "website_url" {
  description = "Public website endpoint of the static site"
  value       = data.aws_s3_bucket.static_site.website_endpoint
}
