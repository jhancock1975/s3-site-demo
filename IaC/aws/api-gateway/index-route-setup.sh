#!/bin/bash
set -euo pipefail
trap 'echo "❌ Error on line $LINENO"' ERR

# fail if any of the vars are not set
: "${REGION:?Need to set REGION}"
: "${ACCOUNT_ID:?Need to set ACCOUNT_ID}"
: "${USER_POOL_ID:?Need to set USER_POOL_ID}"
: "${CLIENT_ID:?Need to set CLIENT_ID}"
: "${BUCKET_NAME:?Need to set BUCKET_NAME}"

echo "🔨 Building Lambda function..."
# Navigate to Lambda directory and build using Make
pushd .
script_dir=$(pwd)
cd "../../../lambda/index-authorizer"
make clean package

# Copy deployment package to API Gateway setup directory
echo "📦 Copying deployment package..."
cp deployment.zip $script_dir

# Change to API Gateway setup directory
popd

# 3.1 Trust policy for Lambda
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Service": "lambda.amazonaws.com" },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Check if role exists first
if aws iam get-role --role-name lambda-cognito-role > /dev/null 2>&1; then
    echo "Role lambda-cognito-role already exists, updating assume role policy..."
    aws iam update-assume-role-policy \
        --role-name lambda-cognito-role \
        --policy-document file://trust-policy.json
else
    echo "Creating IAM role lambda-cognito-role..."
    aws iam create-role \
        --role-name lambda-cognito-role \
        --assume-role-policy-document file://trust-policy.json
fi

# Attach basic execution policy (idempotent operation)
echo "Attaching basic execution policy..."
aws iam attach-role-policy \
    --role-name lambda-cognito-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole || true

# 3.4 Inline policy: allow reading your bucket
cat > s3-read-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
  }]
}
EOF

echo "Adding S3 read policy..."
aws iam put-role-policy \
  --role-name lambda-cognito-role \
  --policy-name S3ReadIndexFiles \
  --policy-document file://s3-read-policy.json

# Wait for role propagation
echo "Waiting for IAM role to propagate..."
sleep 10

# 5.3 Create or update the function (with BUCKET_NAME env var)
if aws lambda get-function --function-name serveIndex --region ${REGION} > /dev/null 2>&1; then
    echo "Lambda function serveIndex already exists, updating..."
    # Update function code
    aws lambda update-function-code \
        --function-name serveIndex \
        --zip-file fileb://deployment.zip \
        --region ${REGION}
    
    # Wait for the update to complete
    echo "Waiting for function update to complete..."
    aws lambda wait function-updated \
        --function-name serveIndex \
        --region ${REGION}
    
    # Update function configuration
    aws lambda update-function-configuration \
        --function-name serveIndex \
        --runtime provided.al2023 \
        --handler bootstrap \
        --environment "Variables={BUCKET_NAME=${BUCKET_NAME}}" \
        --region ${REGION}
    
    # Wait for configuration update to complete
    echo "Waiting for configuration update to complete..."
    aws lambda wait function-updated \
        --function-name serveIndex \
        --region ${REGION}
else
    echo "Creating Lambda function serveIndex..."
    aws lambda create-function \
        --function-name serveIndex \
        --runtime provided.al2023 \
        --handler bootstrap \
        --zip-file fileb://deployment.zip \
        --role arn:aws:iam::${ACCOUNT_ID}:role/lambda-cognito-role \
        --environment "Variables={BUCKET_NAME=${BUCKET_NAME}}" \
        --region ${REGION}
fi

# 6.1 Create the HTTP API or get existing one
API_NAME="serve-index-api"
echo "Checking if API ${API_NAME} exists..."
API_ID=$(aws apigatewayv2 get-apis \
    --region ${REGION} \
    --query "Items[?Name=='${API_NAME}'].ApiId" \
    --output text)

if [ -z "$API_ID" ]; then
    echo "Creating API ${API_NAME}..."
    API_ID=$(aws apigatewayv2 create-api \
        --name ${API_NAME} \
        --protocol-type HTTP \
        --region ${REGION} \
        --query ApiId --output text)
else
    echo "API ${API_NAME} already exists with ID: ${API_ID}"
fi

# 6.2 JWT authorizer pointing at your User Pool
AUTH_NAME="cognito-jwt"
echo "Checking if authorizer ${AUTH_NAME} exists..."
AUTH_ID=$(aws apigatewayv2 get-authorizers \
    --api-id ${API_ID} \
    --region ${REGION} \
    --query "Items[?Name=='${AUTH_NAME}'].AuthorizerId" \
    --output text)

if [ -z "$AUTH_ID" ]; then
    echo "Creating authorizer ${AUTH_NAME}..."
    AUTH_ID=$(aws apigatewayv2 create-authorizer \
        --api-id ${API_ID} \
        --authorizer-type JWT \
        --name ${AUTH_NAME} \
        --identity-source '$request.header.Authorization' \
        --jwt-configuration "Issuer=https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID},Audience=[\"${CLIENT_ID}\"]" \
        --region ${REGION} \
        --query AuthorizerId --output text)
else
    echo "Authorizer ${AUTH_NAME} already exists with ID: ${AUTH_ID}"
fi

# 6.3 Lambda integration
echo "Checking if integration exists..."
LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function:serveIndex"
INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
    --api-id ${API_ID} \
    --region ${REGION} \
    --query "Items[?IntegrationUri=='arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations'].IntegrationId" \
    --output text)

if [ -z "$INTEGRATION_ID" ]; then
    echo "Creating Lambda integration..."
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id ${API_ID} \
        --integration-type AWS_PROXY \
        --integration-uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations \
        --payload-format-version "2.0" \
        --region ${REGION} \
        --query IntegrationId --output text)
else
    echo "Integration already exists with ID: ${INTEGRATION_ID}"
fi

# 6.4 Allow API Gateway to invoke the Lambda
echo "Adding Lambda permission for API Gateway..."
STATEMENT_ID="apigw-permission-${API_ID}"
if ! aws lambda get-policy --function-name serveIndex --region ${REGION} 2>/dev/null | grep -q "${STATEMENT_ID}"; then
    aws lambda add-permission \
        --function-name serveIndex \
        --statement-id ${STATEMENT_ID} \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/* \
        --region ${REGION}
else
    echo "Lambda permission already exists"
fi

# 6.5 Create or update GET / route using the JWT authorizer
echo "Checking if route 'GET /' exists..."
ROUTE_ID=$(aws apigatewayv2 get-routes \
    --api-id ${API_ID} \
    --region ${REGION} \
    --query "Items[?RouteKey=='GET /'].RouteId" \
    --output text)

if [ -z "$ROUTE_ID" ]; then
    echo "Creating route 'GET /'..."
    aws apigatewayv2 create-route \
        --api-id ${API_ID} \
        --route-key 'GET /' \
        --target integrations/${INTEGRATION_ID} \
        --authorizer-id ${AUTH_ID} \
        --authorization-type JWT \
        --region ${REGION}
else
    echo "Route 'GET /' already exists, updating..."
    aws apigatewayv2 update-route \
        --api-id ${API_ID} \
        --route-id ${ROUTE_ID} \
        --target integrations/${INTEGRATION_ID} \
        --authorizer-id ${AUTH_ID} \
        --authorization-type JWT \
        --region ${REGION}
fi

# 6.6 Check if $default stage exists
echo "Checking if default stage exists..."
if aws apigatewayv2 get-stage --api-id ${API_ID} --stage-name '$default' --region ${REGION} > /dev/null 2>&1; then
    echo "Default stage already exists, enabling auto-deploy..."
    aws apigatewayv2 update-stage \
        --api-id ${API_ID} \
        --stage-name '$default' \
        --auto-deploy \
        --region ${REGION}
else
    echo "Creating default stage with auto-deploy..."
    # First create a deployment
    DEPLOYMENT_ID=$(aws apigatewayv2 create-deployment \
        --api-id ${API_ID} \
        --region ${REGION} \
        --query DeploymentId --output text)
    
    # Then create the stage
    aws apigatewayv2 create-stage \
        --api-id ${API_ID} \
        --stage-name '$default' \
        --deployment-id ${DEPLOYMENT_ID} \
        --auto-deploy \
        --region ${REGION}
fi

# Clean up temporary files
rm -f trust-policy.json s3-read-policy.json

echo "✅ Setup complete!"
echo "Your API is live at: https://${API_ID}.execute-api.${REGION}.amazonaws.com/"