resource "aws_acm_certificate" "taptupo_cert" {
  domain_name       = "taptupo.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

