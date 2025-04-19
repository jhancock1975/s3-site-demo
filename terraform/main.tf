provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "static_site" {
  bucket = var.s3_bucket_name

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    Name = "StaticSite"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      website,
      tags,
    ]
  }
}

resource "aws_s3_bucket_policy" "allow_public_access" {
  bucket = aws_s3_bucket.static_site.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid:       "PublicReadGetObject",
        Effect:    "Allow",
        Principal: "*",
        Action:    "s3:GetObject",
        Resource:  "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}
