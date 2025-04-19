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
  # constant bucket name
  bucket_name = "s3-bucket-demo-jh-2025-04-19"
}

# Reference the existing bucket
data "aws_s3_bucket" "static_site" {
  bucket = local.bucket_name
}

# Configure it for static website hosting
resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = data.aws_s3_bucket.static_site.id

  index_document {
    suffix = "index.html"
  }
}

# Build a public-read policy document
data "aws_iam_policy_document" "public_read" {
  statement {
    sid       = "AllowPublicReadGetObject"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${data.aws_s3_bucket.static_site.arn}/*"]
  }
}

# Attach the policy to your existing bucket
resource "aws_s3_bucket_policy" "public_read" {
  bucket = data.aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.public_read.json
}

# Upload index.html
resource "aws_s3_bucket_object" "index" {
  bucket       = data.aws_s3_bucket.static_site.id
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
  acl          = "public-read"
}
