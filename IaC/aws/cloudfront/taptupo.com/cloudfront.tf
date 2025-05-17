resource "aws_cloudfront_distribution" "taptupo" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = ""
  default_root_object = "index.html"
  price_class         = "PriceClass_All"
  http_version        = "http2"
  web_acl_id          = "arn:aws:wafv2:us-east-1:071350569379:global/webacl/CreatedByCloudFront-007e35a5/c7ec1ee2-03f0-4755-af2a-62a40e68a951"

  aliases = ["taptupo.com"]

  origin {
    domain_name = "taptupo.com.s3.us-east-1.amazonaws.com"
    origin_id   = "taptupo.com_

