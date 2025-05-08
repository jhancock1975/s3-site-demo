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
