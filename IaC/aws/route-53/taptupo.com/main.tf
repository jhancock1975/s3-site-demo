provider "aws" {
  region = "us-east-1" # Change to your actual region
}

resource "aws_s3_bucket" "taptupo" {
  bucket = "taptupo.com"
  acl    = "private"
  force_destroy = true

  tags = {
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_policy" "taptupo_policy" {
  bucket = aws_s3_bucket.taptupo.id
  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "PolicyForCloudFrontPrivateContent"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipal"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "arn:aws:s3:::taptupo.com/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::071350569379:distribution/E2PN7XL8XHCRZX"
          }
        }
      }
    ]
  })
}

