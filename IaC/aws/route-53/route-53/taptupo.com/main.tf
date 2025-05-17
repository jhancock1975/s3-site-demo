provider "aws" {
  region = "us-east-1" # or wherever you're managing DNS
}

resource "aws_route53_zone" "taptupo" {
  name = "taptupo.com"
}

