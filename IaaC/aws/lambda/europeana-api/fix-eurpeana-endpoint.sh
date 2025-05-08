#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO: \`$BASH_COMMAND\` failed (exit $?)"' ERR

AWS_REGION="us-east-1"
DOMAIN_NAME="api.taptupo.com"
API_ID="uaylfafva3"         # your Europeana API ID
STAGE="prod"

echo "🔍 Removing any existing /europeana-search mapping…"
# find the mapping for key "europeana-search"
OLD_MAP_ID=$(aws apigatewayv2 get-api-mappings \
  --domain-name "$DOMAIN_NAME" \
  --region "$AWS_REGION" \
  --query "Items[?ApiMappingKey=='europeana-search'].ApiMappingId | [0]" \
  --output text || echo "")

if [[ -n "$OLD_MAP_ID" && "$OLD_MAP_ID" != "None" ]]; then
  aws apigatewayv2 delete-api-mapping \
    --domain-name "$DOMAIN_NAME" \
    --api-mapping-id "$OLD_MAP_ID" \
    --region "$AWS_REGION"
  echo "→ Deleted old mapping (ID: $OLD_MAP_ID)"
else
  echo "→ No old mapping found."
fi

echo "🔧 Creating new root‐path mapping (so /europeana-search → /europeana-search)…"
aws apigatewayv2 create-api-mapping \
  --domain-name "$DOMAIN_NAME" \
  --region "$AWS_REGION" \
  --api-id "$API_ID" \
  --stage "$STAGE" \
  --api-mapping-key "" 
echo "→ New mapping created."

echo
echo "🔎 Testing endpoint…"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN_NAME}/europeana-search")
if [[ "$STATUS" -eq 200 ]]; then
  echo "✅ Success! HTTP $STATUS"
else
  echo "❌ Still got HTTP $STATUS"
  exit 1
fi


###
# This script enables CORS on your Europeana HTTP API
# and then tests that your browser‐facing endpoint returns 200.
###

# CONFIGURATION
AWS_REGION="us-east-1"
API_NAME="europeana-api"                  # name of your HTTP API
ORIGIN="https://taptupo.com"              # allowed origin
ENDPOINT="https://api.taptupo.com/europeana-search"  # your custom‐domain URL

# 1) Look up the HTTP API’s ID
API_ID=$(aws apigatewayv2 get-apis \
  --region "$AWS_REGION" \
  --query "Items[?Name=='${API_NAME}'].ApiId | [0]" \
  --output text)
if [[ -z "$API_ID" || "$API_ID" == "None" ]]; then
  echo "❌ API '$API_NAME' not found in region $AWS_REGION"
  exit 1
fi
echo "→ Found API_ID: $API_ID"

# 2) Enable CORS
echo "→ Applying CORS configuration for origin $ORIGIN"
aws apigatewayv2 update-api \
  --api-id "$API_ID" \
  --region "$AWS_REGION" \
  --cors-configuration \
AllowOrigins='["'"$ORIGIN"'"]',\
AllowMethods='["GET","OPTIONS"]',\
AllowHeaders='["*"]',\
ExposeHeaders='["*"]',\
MaxAge=86400
echo "→ CORS configuration applied"

# 3) Test the endpoint
echo -n "→ Testing GET $ENDPOINT ... "
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$ENDPOINT")
if [[ "$HTTP_CODE" -ne 200 ]]; then
  echo "❌ got HTTP $HTTP_CODE"
  exit 1
else
  echo "✅ got HTTP 200 OK"
fi
