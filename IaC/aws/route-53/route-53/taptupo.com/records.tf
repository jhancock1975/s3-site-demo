# A Record pointing to CloudFront
resource "aws_route53_record" "a_root" {
  zone_id = aws_route53_zone.taptupo.zone_id
  name    = "taptupo.com"
  type    = "A"

  alias {
    name                   = "d3s1lwcqxkwnp7.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

# CNAME validation record (e.g., for ACM)
resource "aws_route53_record" "cname_validation" {
  zone_id = aws_route53_zone.taptupo.zone_id
  name    = "_0f5e2992b1acf0412548e0b46c9ae700.taptupo.com"
  type    = "CNAME"
  ttl     = 300
  records = ["_cadb0f7e3e853a282cc589b457ab3395.xlfgrmvvlj.acm-validations.aws."]
}

