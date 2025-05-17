#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\` failed with exit code $?"; exit 1' ERR

###
# Builds & deploys the GPT-4O Lambda, configures HTTP API route POST /gpt-4o,
# enables CORS, tests the raw AWS endpoint, maps it under your custom domain,
# then tests the custom-domain endpoint.
# This script lives alongside your Go handler(s).
###

# --- Configuration ---
AWS_REGION="us-east-1"
ROLE_NAME="gpt4-handler-role"
API_NAME="europeana-api"
STAGE="prod"
LAMBDA_NAME="gpt4-handler"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$SCRIPT_DIR"
ZIP_PATH="$CODE_DIR/function.zip"
ROUTE_KEY="POST /gpt-4o"
DOMAIN_NAME="api.taptupo.com"
ORIGIN="https://taptupo.com"
# ----------------------

# 1) Prompt for OpenAI key & store in SSM
read -rsp "Enter OpenAI API key: " OPENAI_KEY; echo
aws ssm put-parameter \
  --name /taptupo/openai/api-key \
  --description "OpenAI GPT-4O API key" \
  --value "$OPENAI_KEY" \
  --type SecureString \
  --overwrite \
  --region "$AWS_REGION"
echo "→ Stored OpenAI key in SSM"

# 2) Ensure IAM role exists & attach policies
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  echo "→ Creating IAM role $ROLE_NAME"
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document '{
      "Version":"2012-10-17",
      "Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]
    }' --region "$AWS_REGION"
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
  aws iam attach-role-policy --role-name "$ROLE_NAME" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess
else
  echo "→ IAM role $ROLE_NAME exists, skipping"
fi
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${ROLE_NAME}"

# 3) Build & package Lambda if any .go is newer than ZIP, or ZIP missing
if [[ ! -f "$ZIP_PATH" ]] || find "$CODE_DIR" -maxdepth 1 -name '*.go' -newer "$ZIP_PATH" | grep -q .; then
  echo "→ Changes detected; building Lambda package"
  pushd "$CODE_DIR" >/dev/null
    if [[ ! -f go.mod ]]; then
      go mod init gpt4_handler
      go get \
        github.com/aws/aws-lambda-go/events \
        github.com/aws/aws-lambda-go/lambda \
        github.com/aws/aws-sdk-go-v2/config \
        github.com/aws/aws-sdk-go-v2/service/ssm
      go mod tidy
    fi
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap .
    zip -j function.zip bootstrap
  popd >/dev/null
else
  echo "→ No .go changes since last build; skipping build"
fi

# 4) Create or update the Lambda function
if aws lambda get-function --function-name "$LAMBDA_NAME" &>/dev/null; then
  echo "→ Updating Lambda code"
  aws lambda update-function-code \
    --function-name "$LAMBDA_NAME" \
    --zip-file fileb://"$ZIP_PATH" \
    --region "$AWS_REGION"
else
  echo "→ Creating Lambda function"
  aws lambda create-function \
    --function-name "$LAMBDA_NAME" \
    --runtime provided.al2 \
    --handler bootstrap \
    --role "$ROLE_ARN" \
    --zip-file fileb://"$ZIP_PATH" \
    --architectures x86_64 \
    --publish \
    --region "$AWS_REGION"
fi

# 5) Grant API GW permission (skip conflict)
echo "→ Ensuring API Gateway invoke permission"
if ! aws lambda add-permission \
    --function-name "$LAMBDA_NAME" \
    --statement-id api-gw-invoke \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):*/*/*" \
    --region "$AWS_REGION"; then
  echo "→ Permission already exists, skipping"
fi

# 6) Lookup existing API ID
API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text)
[[ -n "$API_ID" && "$API_ID" != "None" ]] || { echo "❌ API '$API_NAME' not found"; exit 1; }
echo "→ Using API_ID: $API_ID"
AWS_INVOKE_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}/gpt-4o"
CUSTOM_URL="https://${DOMAIN_NAME}/gpt-4o"

# 7) Create or reuse Lambda-proxy integration
LAMBDA_ARN=$(aws lambda get-function --function-name "$LAMBDA_NAME" \
  --query 'Configuration.FunctionArn' --output text --region "$AWS_REGION")
INT_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id "$API_ID" --region "$AWS_REGION" \
  --query "Items[?IntegrationUri=='${INT_URI}'].IntegrationId | [0]" \
  --output text)
if [[ -n "$INTEGRATION_ID" && "$INTEGRATION_ID" != "None" ]]; then
  echo "→ Reusing IntegrationId: $INTEGRATION_ID"
else
  echo "→ Creating integration"
  INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --region "$AWS_REGION" \
    --integration-type AWS_PROXY \
    --integration-uri "$INT_URI" \
    --payload-format-version 2.0 \
    --query IntegrationId --output text)
fi

# 8) Re-create route POST /gpt-4o
echo "→ (Re)creating route $ROUTE_KEY"
set +e
OLD_ROUTE_ID=$(aws apigatewayv2 get-routes \
  --api-id "$API_ID" \
  --query "Items[?RouteKey=='$ROUTE_KEY'].RouteId | [0]" \
  --output text)
if [[ -n "$OLD_ROUTE_ID" && "$OLD_ROUTE_ID" != "None" ]]; then
  aws apigatewayv2 delete-route \
    --api-id "$API_ID" \
    --route-id "$OLD_ROUTE_ID" \
    --region "$AWS_REGION"
fi
set -e
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --route-key "$ROUTE_KEY" \
  --target integrations/"$INTEGRATION_ID"

# 9) Ensure prod stage exists & redeploy
echo "→ Ensuring stage $STAGE (auto-deploy)"
if aws apigatewayv2 get-stage \
     --api-id "$API_ID" \
     --stage-name "$STAGE" \
     --region "$AWS_REGION" &>/dev/null; then
  aws apigatewayv2 update-stage \
    --api-id "$API_ID" \
    --stage-name "$STAGE" \
    --auto-deploy \
    --region "$AWS_REGION"
else
  aws apigatewayv2 create-stage \
    --api-id "$API_ID" \
    --stage-name "$STAGE" \
    --auto-deploy \
    --region "$AWS_REGION"
fi

# 10) Enable CORS
echo "→ Enabling CORS"
aws apigatewayv2 update-api \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --cors-configuration \
AllowOrigins='["'"$ORIGIN"'"]',\
AllowMethods='["POST","OPTIONS"]',\
AllowHeaders='["*"]',\
ExposeHeaders='["*"]',\
MaxAge=86400

# 11) Test AWS execute-api endpoint (verbose)
echo "→ Testing AWS endpoint POST $AWS_INVOKE_URL …"
curl -v \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"prompt":"hello"}' \
  "$AWS_INVOKE_URL" || echo "↳ (curl exit $? — check headers above)"

# 12) Ensure custom-domain root mapping exists
echo "→ Ensuring custom-domain root mapping"
if ! aws apigatewayv2 get-api-mappings \
      --domain-name "$DOMAIN_NAME" \
      --region "$AWS_REGION" \
      --query "Items[?ApiMappingKey==''].ApiMappingId" \
      --output text | grep -q .; then
  aws apigatewayv2 create-api-mapping \
    --domain-name "$DOMAIN_NAME" \
    --api-id "$API_ID" \
    --stage "$STAGE" \
    --api-mapping-key "" \
    --region "$AWS_REGION"
  echo "→ Created root base-path mapping"
else
  echo "→ Root mapping exists, skipping"
fi

# 13) Test custom-domain endpoint (verbose)
echo "→ Testing custom-domain POST $CUSTOM_URL …"
curl -v \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"prompt":"hello"}' \
  "$CUSTOM_URL" || echo "↳ (curl exit $? — check headers above)"

echo "✅ Deployment & test complete!"
