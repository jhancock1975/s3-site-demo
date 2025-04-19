output "website_url" {
  description = "Public URL of the static site"
  value       = aws_s3_bucket.static_site.website_endpoint
}
