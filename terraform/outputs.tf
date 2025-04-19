output "s3_website_endpoint" {
  value = aws_s3_bucket.static_site.website_endpoint
}

output "cloudflare_dns" {
  value = cloudflare_record.site_cname.hostname
}
