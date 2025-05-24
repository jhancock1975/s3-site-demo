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

# 3.2 Create the role
aws iam create-role \
  --role-name lambda-cognito-role \
  --assume-role-policy-document file://trust-policy.json

# 3.3 Attach basic execution policy
aws iam attach-role-policy \
  --role-name lambda-cognito-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

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

aws iam put-role-policy \
  --role-name lambda-cognito-role \
  --policy-name S3ReadIndexFiles \
  --policy-document file://s3-read-policy.json


# 5.3 Create the function (with BUCKET_NAME env var)
aws lambda create-function \
  --function-name serveIndex \
  --runtime provided.al2023 \
  --handler main \
  --zip-file fileb://deployment.zip \
  --role arn:aws:iam::${ACCOUNT_ID}:role/lambda-cognito-role \
  --environment "Variables={BUCKET_NAME=${BUCKET_NAME}}" \
  --region ${REGION}


  # 6.1 Create the HTTP API
API_ID=$(aws apigatewayv2 create-api \
  --name serve-index-api \
  --protocol-type HTTP \
  --region ${REGION} \
  --query ApiId --output text)

# 6.2 JWT authorizer pointing at your User Pool
AUTH_ID=$(aws apigatewayv2 create-authorizer \
  --api-id ${API_ID} \
  --authorizer-type JWT \
  --name cognito-jwt \
  --identity-source '$request.header.Authorization' \
  --jwt-configuration "Issuer=https://cognito-idp.${REGION}.amazonaws.com/${USER_POOL_ID},Audience=[\"${CLIENT_ID}\"]" \
  --region ${REGION} \
  --query AuthorizerId --output text)

# 6.3 Lambda integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id ${API_ID} \
  --integration-type AWS_PROXY \
  --integration-uri arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${ACCOUNT_ID}:${REGION}:function:serveIndex/invocations \
  --region ${REGION} \
  --query IntegrationId --output text)

# 6.4 Allow API Gateway to invoke the Lambda
aws lambda add-permission \
  --function-name serveIndex \
  --statement-id apigw-permission \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*/*/* \
  --region ${REGION}

# 6.5 Create GET / route using the JWT authorizer
aws apigatewayv2 create-route \
  --api-id ${API_ID} \
  --route-key 'GET /' \
  --target integrations/${INTEGRATION_ID} \
  --authorizer-id ${AUTH_ID} \
  --authorization-type JWT \
  --region ${REGION}

# 6.6 Deploy to $default with auto-deploy
aws apigatewayv2 update-stage \
  --api-id ${API_ID} \
  --stage-name '$default' \
  --auto-deploy \
  --region ${REGION}

echo "Your API is live at: https://${API_ID}.execute-api.${REGION}.amazonaws.com/"
