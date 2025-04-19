terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  # <-- your “constant” bucket name
  bucket_name = "my-static-site-bucket-12345"
}

# Create the bucket with static-website hosting
resource "aws_s3_bucket" "static_site" {
  bucket = local.bucket_name
  acl    = "public-read"

  website {
    index_document = "index.html"
  }
}

# Public-read policy
data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "AllowPublicReadGetObject"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static_site.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.public_read.json
}

# Upload your index.html
resource "aws_s3_bucket_object" "index" {
  bucket       = aws_s3_bucket.static_site.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"
}
