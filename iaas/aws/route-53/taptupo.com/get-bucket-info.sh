#!/bin/bash
# This script retrieves various configurations and settings for the S3 bucket "taptupo.com"
# Get bucket policy
aws s3api get-bucket-policy --bucket taptupo.com > bucket-policy.json

# Get bucket versioning
aws s3api get-bucket-versioning --bucket taptupo.com > versioning.json

# Get lifecycle configuration
aws s3api get-bucket-lifecycle-configuration --bucket taptupo.com > lifecycle.json

# Get bucket ACL
aws s3api get-bucket-acl --bucket taptupo.com > acl.json

# Get bucket tags
aws s3api get-bucket-tagging --bucket taptupo.com > tags.json
