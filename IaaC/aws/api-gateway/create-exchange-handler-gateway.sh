# this script is to create the
# exchange handler gateway for the exchange handler lambda

# 0) Grab your AWS Account ID and set some variables
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
LAMBDA_NAME=exchangeHandler
REGION=${AWS_REGION:-us-east-1}

# 1) Create the REST API
API_ID=$(aws apigateway create-rest-api \
  --name exchange-api \
  --description "Proxy /exchange to Lambda" \
  --region $REGION \
  --query 'id' --output text)

echo "Created API: $API_ID"

# 2) Find the root resource ID
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --region $REGION \
  --query 'items[?path==`/`].id' --output text)

# 3) Create the /exchange resource
EX_RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part exchange \
  --region $REGION \
  --query 'id' --output text)

echo "Created /exchange resource: $EX_RESOURCE_ID"

# 4) Enable POST method on /exchange (no auth)
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION

# 5) Wire POST into your Lambda via AWS_PROXY
LAMBDA_ARN="arn:aws:lambda:$REGION:$ACCOUNT_ID:function:$LAMBDA_NAME"
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/$LAMBDA_ARN/invocations" \
  --region $REGION

# 6) Grant API Gateway permission to invoke your Lambda
aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id apigateway-invoke-exchange \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/POST/exchange" \
  --region $REGION

# 7) Enable CORS: create OPTIONS on /exchange as MOCK
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method OPTIONS \
  --authorization-type NONE \
  --region $REGION \
  --request-parameters method.request.header.Origin=true

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method OPTIONS \
  --type MOCK \
  --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
  --region $REGION

aws apigateway put-method-response \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Origin": true,
    "method.response.header.Access-Control-Allow-Methods": true,
    "method.response.header.Access-Control-Allow-Headers": true
  }' \
  --region $REGION

aws apigateway put-integration-response \
  --rest-api-id $API_ID \
  --resource-id $EX_RESOURCE_ID \
  --http-method OPTIONS \
  --status-code 200 \
  --response-parameters '{
    "method.response.header.Access-Control-Allow-Origin": "'\''*'\''",
    "method.response.header.Access-Control-Allow-Methods": "'\''POST,OPTIONS'\''",
    "method.response.header.Access-Control-Allow-Headers": "'\''Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'\''"
  }' \
  --region $REGION
# 8) Deploy a 'prod' stage
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --region $REGION

echo "API deployed! Invoke URL:"
echo "  https://$API_ID.execute-api.$REGION.amazonaws.com/prod/exchange"
