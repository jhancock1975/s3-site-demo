# Terraform + GitHub Actions Repository

This repository provisions an AWS S3 static website, AWS Lambda function (Go), API Gateway, and Cloudflare DNS record using Terraform. It also includes a GitHub Actions workflow to build and deploy.

## Setup

1. Create a GitHub repository and push these files.
2. In your GitHub repository settings, add the following Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ZONE_ID`
   - `CLOUDFLARE_RECORD_ID`
   - `DOMAIN_NAME`
   - `S3_BUCKET_NAME`

3. Ensure your AWS IAM user has the permissions to:
   - Create S3 buckets and objects.
   - Create IAM roles and attach policies.
   - Create Lambda functions.
   - Create API Gateway resources.

4. Ensure your Cloudflare API token has permissions to edit DNS records.

5. Merge to the `main` branch. The GitHub Actions workflow will run automatically and provision the infrastructure.

## Usage

After a successful deployment:

- Your site will be available at `http://<DOMAIN_NAME>`.
- The API endpoint is output by Terraform (check the GitHub Actions logs or use `terraform output api_endpoint`).
