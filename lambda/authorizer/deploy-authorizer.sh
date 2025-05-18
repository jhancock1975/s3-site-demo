#!/bin/bash
set -euo pipefail

# Print error and line number if script fails
trap 'echo "Error on line $LINENO"; exit 1' ERR

# Build Go Lambda binary
echo "Compiling Go Lambda (authorizer.go)..."
GOOS=linux GOARCH=amd64 go build -o bootstrap authorizer.go

# Zip it
echo "Zipping binary..."
zip -q lambda-authorizer.zip bootstrap

# Update Lambda function code
echo "Updating Lambda function s3-site-demo-authorizer..."
aws lambda update-function-code \
  --function-name s3-site-demo-authorizer \
  --zip-file fileb://lambda-authorizer.zip

echo "Deployment complete!"
