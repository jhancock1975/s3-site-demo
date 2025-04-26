# this script is for exporting the exchange handler gateway for the exchange handler lambda

# 1) List your APIs (to verify your API_ID)
aws apigateway get-rest-apis \
  --output table
export API_ID="4aaqrkm65b"
export STAGE="prod"

# 2) (Optional) Dump out all resources & methods
aws apigateway get-resources \
  --rest-api-id $API_ID \
  --output json > api-resources.json

# 3) Export as OpenAPI (OAS 3.0) including integrations
aws apigateway get-export \
  --rest-api-id $API_ID \
  --stage-name $STAGE \
  --export-type oas30 \
  --parameters extensions='integrations' \
  --accepts application/json \
  api-export.json

# After this, api-export.json will contain your full API Gateway config
