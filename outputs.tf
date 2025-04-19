output "website_url" {
  description = "URL of the static website"
  value       = aws_s3_bucket.website.website_endpoint
}
