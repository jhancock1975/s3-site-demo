#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\` failed with exit code $?"; exit 1' ERR

if [ $# -ne 1 ]; then
  echo "Usage: $0 <Name>"
  exit 1
fi

# --- Inputs & naming ---
NAME="$1"
NAME_LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')
HANDLER_DIR="lambda/${NAME_LOWER}_handler"
API_NAME="${NAME_LOWER}-api"
DOMAIN_NAME="api.taptupo.com"
STAGE="prod"
AWS_REGION="us-east-1"
ROLE_NAME="${NAME_LOWER}-handler-role"
ZIP_PATH="$HANDLER_DIR/function.zip"
ROUTE_KEY="ANY /${NAME_LOWER}"
ORIGIN="https://taptupo.com"
# -----------------------

# 1) Scaffold handler from template if missing
if [ ! -d "$HANDLER_DIR" ]; then
  echo "→ Scaffolding handler in $HANDLER_DIR"
  mkdir -p "$HANDLER_DIR"

  # Copy & render Makefile
  cp lambda/lambda-go-template/Makefile.template "$HANDLER_DIR"/Makefile.template
  export MODULE_NAME="$NAME_LOWER"
  envsubst < "$HANDLER_DIR"/Makefile.template > "$HANDLER_DIR"/Makefile
  rm "$HANDLER_DIR"/Makefile.template

  # Copy Go source stubs so *.go actually exists
  cp lambda/lambda-go-template/*.go "$HANDLER_DIR"/
fi

# 2) Build & package Lambda if any .go changed or ZIP missing
echo "→ Checking for Go source changes..."
if [[ ! -f "$ZIP_PATH" ]] || find "$HANDLER_DIR" -maxdepth 1 -name '*.go' -newer "$ZIP_PATH" | grep -q .; then
  echo "→ Building & packaging $NAME handler"
  pushd "$HANDLER_DIR" >/dev/null

    if [[ ! -f go.mod ]]; then
      go mod init "$NAME_LOWER"
    fi

    go mod tidy
    GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap *.go
    zip -j function.zip bootstrap

  popd >/dev/null
else
  echo "→ No changes in Go source; skipping build"
fi

# 3) Ensure IAM role exists
echo "→ Ensuring IAM role $ROLE_NAME"
if ! aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
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
  echo "→ IAM role exists, skipping"
fi
ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/${ROLE_NAME}"

# 4) Create or update Lambda function
echo "→ Deploying Lambda $NAME_LOWER"
if aws lambda get-function --function-name "$NAME_LOWER" &>/dev/null; then
  aws lambda update-function-code \
    --function-name "$NAME_LOWER" \
    --zip-file fileb://"$ZIP_PATH" \
    --region "$AWS_REGION"
else
  aws lambda create-function \
    --function-name "$NAME_LOWER" \
    --runtime provided.al2 \
    --handler bootstrap \
    --role "$ROLE_ARN" \
    --zip-file fileb://"$ZIP_PATH" \
    --architectures x86_64 \
    --publish \
    --region "$AWS_REGION"
fi

# 5) Grant API GW permission (idempotent)
echo "→ Granting API Gateway invoke permission"
aws lambda add-permission \
  --function-name "$NAME_LOWER" \
  --statement-id api-gw-invoke-${NAME_LOWER} \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:$(aws sts get-caller-identity --query Account --output text):*/*/*" \
  --region "$AWS_REGION" 2>/dev/null || echo "→ Permission exists"

# 6) Create or reuse HTTP API
echo "→ Ensuring HTTP API $API_NAME"
API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text)
if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
  API_ID=$(aws apigatewayv2 create-api \
    --name "$API_NAME" \
    --protocol-type HTTP \
    --region "$AWS_REGION" \
    --query ApiId --output text)
fi

# 7) Create or reuse integration
echo "→ Configuring integration"
LAMBDA_ARN=$(aws lambda get-function --function-name "$NAME_LOWER" \
  --query 'Configuration.FunctionArn' --output text --region "$AWS_REGION")
INT_URI="arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations"
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
  --api-id "$API_ID" --region "$AWS_REGION" \
  --query "Items[?IntegrationUri=='${INT_URI}'].IntegrationId | [0]" \
  --output text)
if [[ -z "$INTEGRATION_ID" || "$INTEGRATION_ID" == "None" ]]; then
  INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id "$API_ID" \
    --integration-type AWS_PROXY \
    --integration-uri "$INT_URI" \
    --payload-format-version 2.0 \
    --region "$AWS_REGION" \
    --query IntegrationId --output text)
fi

# 8) Create or replace route
echo "→ (Re)creating route $ROUTE_KEY"
OLD_ROUTE=$(aws apigatewayv2 get-routes \
  --api-id "$API_ID" --region "$AWS_REGION" \
  --query "Items[?RouteKey=='$ROUTE_KEY'].RouteId | [0]" \
  --output text)
if [[ -n "$OLD_ROUTE" && "$OLD_ROUTE" != "None" ]]; then
  aws apigatewayv2 delete-route \
    --api-id "$API_ID" \
    --route-id "$OLD_ROUTE" \
    --region "$AWS_REGION"
fi
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key "$ROUTE_KEY" \
  --target integrations/"$INTEGRATION_ID" \
  --region "$AWS_REGION"

# 9) Deploy or update stage
echo "→ Deploying stage $STAGE"
if aws apigatewayv2 get-stage --api-id "$API_ID" --stage-name "$STAGE" --region "$AWS_REGION" &>/dev/null; then
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
echo "→ Enabling CORS for $ORIGIN"
aws apigatewayv2 update-api \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --cors-configuration \
'{"AllowOrigins":["'"$ORIGIN"'"],"AllowMethods":["GET","POST","PUT","DELETE","OPTIONS"],"AllowHeaders":["*"],"ExposeHeaders":["*"],"MaxAge":86400}'

# 11) Map custom domain at root (so /foo → /foo in the API)
echo "→ Mapping custom domain to root path"
# Delete any old “foo”-key mapping so we don’t collide
OLD_MAPPING_ID=$(aws apigatewayv2 get-api-mappings \
  --domain-name "$DOMAIN_NAME" \
  --region "$AWS_REGION" \
  --query "Items[?ApiMappingKey=='${NAME_LOWER}'].ApiMappingId | [0]" \
  --output text)
if [[ -n "$OLD_MAPPING_ID" && "$OLD_MAPPING_ID" != "None" ]]; then
  aws apigatewayv2 delete-api-mapping \
    --domain-name "$DOMAIN_NAME" \
    --api-mapping-id "$OLD_MAPPING_ID" \
    --region "$AWS_REGION"
  echo "→ Deleted old mapping for /${NAME_LOWER}"
fi
# Ensure a ROOT mapping exists (omit --api-mapping-key for “/”)
ROOT_MAPPING_ID=$(aws apigatewayv2 get-api-mappings \
  --domain-name "$DOMAIN_NAME" \
  --region "$AWS_REGION" \
  --query "Items[?ApiMappingKey==''].ApiMappingId | [0]" \
  --output text)
if [[ -z "$ROOT_MAPPING_ID" || "$ROOT_MAPPING_ID" == "None" ]]; then
  aws apigatewayv2 create-api-mapping \
    --domain-name "$DOMAIN_NAME" \
    --api-id "$API_ID" \
    --stage "$STAGE" \
    --region "$AWS_REGION"
  echo "→ Created root mapping for $DOMAIN_NAME → /$STAGE"
else
  echo "→ Root mapping already in place"
fi

# 12) Results
DEFAULT_URL="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/${STAGE}/${NAME_LOWER}"
CUSTOM_URL="https://${DOMAIN_NAME}/${NAME_LOWER}"

echo
echo "✅ Deployed $NAME!"
echo "  Default invoke: $DEFAULT_URL"
echo "  Custom invoke:  $CUSTOM_URL"

