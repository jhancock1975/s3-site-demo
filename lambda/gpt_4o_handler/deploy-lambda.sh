#!/usr/bin/env bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"' ERR

# ——— CONFIG ———
FUNCTION_NAME="gpt_4o_handler"
AWS_REGION="us-east-1"
# ————————

echo "→ Building Linux binary"
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap gpt_4o_handler.go

echo "→ Zipping package"
zip -q function.zip bootstrap

echo "→ Updating ${FUNCTION_NAME}"
aws lambda update-function-code \
  --function-name "${FUNCTION_NAME}" \
  --zip-file fileb://function.zip \
  --region "${AWS_REGION}"

echo "✅ Deployment complete"
