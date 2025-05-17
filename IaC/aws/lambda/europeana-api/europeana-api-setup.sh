#!/usr/bin/env bash
set -euo pipefail

# Print error line & command on failure
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\` failed with exit code $?";' ERR

# …rest of your script…

### CONFIGURATION ###
AWS_REGION="us-east-1"
ROLE_NAME="your-lambda-exec-role"         # IAM role name for Lambda
ZIP_PATH="./function.zip"                  # Path to your built bootstrap ZIP
LAMBDA_NAME="europeana-lambda"
API_NAME="europeana-api"
STAGE="prod"
ROUTE_KEY="GET /search"
DOMAIN_NAME="api.taptupo.com"
API_MAPPING_KEY="search"
#####################

# 0. Fetch account ID and build role ARN
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"

# 1. Ensure the IAM role exists & is assumable by Lambda
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  echo "Creating IAM role $ROLE_NAME…"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[
        {
          "Effect":"Allow",
          "Principal":{"Service":"lambda.amazonaws.com"},
          "Action":"sts:AssumeRole"
        }
      ]
    }'
  aws iam wait role-exists --role-name "$ROLE_NAME"

  echo "Attaching AWSLambdaBasicExecutionRole policy…"
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

  echo "Attaching AmazonSSMReadOnlyAccess policy…"
  aws iam attach-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess
else
  echo "IAM role $ROLE_NAME already exists."
fi

# 2. Create or update the Lambda function
if aws lambda get-function --function-name "$LAMBDA_NAME" &>/dev/null; then
  echo "Updating existing Lambda code…"
  aws lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --zip-file fileb://"$ZIP_PATH"
else
  echo "Creating new Lambda function…"
  aws lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime provided.al2 \
    --role "$ROLE_ARN" \
    --handler bootstrap \
    --zip-file fileb://"$ZIP_PATH" \
    --architectures x86_64 \
    --publish
fi

# 3. Grant API Gateway permission to invoke the Lambda
aws lambda add-permission \
  --function-name "$LAMBDA_NAME" \
  --statement-id api-gw-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:*/*/*" \
  || echo "Permission api-gw-invoke already exists."

# 4. Create (or reuse) the HTTP API
API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text)

if [ -z "$API_ID" ] || [ "$API_ID" = "None" ]; then
  echo "Creating HTTP API ${API_NAME}…"
  API_ID=$(aws apigatewayv2 create-api \
    --region "$AWS_REGION" \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --query ApiId --output text)
else
  echo "Reusing existing API ID: $API_ID"
fi

# 5. Create the Lambda‐proxy integration
LAMBDA_ARN=$(aws lambda get-function \
  --function-name "$LAMBDA_NAME" \
  --query 'Configuration.FunctionArn' --output text)

INTEGRATION_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"

INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --integration-type AWS_PROXY \
  --integration-uri "$INTEGRATION_URI" \
  --payload-format-version 2.0 \
  --query IntegrationId --output text)

# 6. Create the GET /search route (idempotent)
if ! aws apigatewayv2 get-routes \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --query "Items[?RouteKey=='$ROUTE_KEY']" \
    --output text | grep -q "$ROUTE_KEY"; then
  echo "Creating route $ROUTE_KEY…"
  aws apigatewayv2 create-route \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --route-key "$ROUTE_KEY" \
    --target integrations/"$INTEGRATION_ID"
else
  echo "Route $ROUTE_KEY already exists."
fi

# 7. Deploy to prod (auto-deploy = true)
if ! aws apigatewayv2 get-stage \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --stage-name "$STAGE" &>/dev/null; then
  echo "Creating stage $STAGE…"
  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --stage-name "$STAGE" \
    --auto-deploy
else
  echo "Stage $STAGE already exists (auto‐deploy enabled)."
fi

# 8. Map under existing custom domain
echo "Mapping /${API_MAPPING_KEY} to ${DOMAIN_NAME}…"
aws apigatewayv2 create-api-mapping \
  --domain-name "$DOMAIN_NAME" \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --stage "$STAGE" \
  --api-mapping-key "$API_MAPPING_KEY" \
  || echo "API mapping /${API_MAPPING_KEY} already exists."

# 9. Output the invoke URLs
echo
echo "Lambda function ARN: $LAMBDA_ARN"
echo "HTTP API ID: $API_ID"
echo "Default endpoint: https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}/search"
echo "Custom domain:  https://${DOMAIN_NAME}/${API_MAPPING_KEY}"
