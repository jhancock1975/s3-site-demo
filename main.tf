# 1) Create the bucket
resource "aws_s3_bucket" "website" {
  bucket = local.bucket_name

  website {
    index_document = "index.html"
  }
}

# 2) Disable S3 Public Access Block so our ACL & policy can take effect
resource "aws_s3_bucket_public_access_block" "public" {
  bucket                  = local.bucket_name
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 3) Add a policy granting public read to all objects
data "aws_iam_policy_document" "public_read" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    actions = ["s3:GetObject"]
    resources = [
      "arn:aws:s3:::${local.bucket_name}/*"
    ]
  }
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.public_read.json
}

# 4) Upload your index.html
resource "aws_s3_bucket_object" "index" {
  bucket       =  local.bucket_name
  key          = "index.html"
  source       = "${path.module}/index.html"
  content_type = "text/html"
}
