#!/usr/bin/env bash
set -euo pipefail
# Trap errors and report the line number of failure
trap 'echo "Error in ${0} at line ${LINENO}" >&2; exit 1' ERR

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

NAME=$1
NAME_LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')

# Paths and templates
template_dir="lambda/lambda-go-template"
code_dir="lambda/${NAME_LOWER}_handler"
api_dir="IaaC/aws/lambda/${NAME_LOWER}-api"
tfv_template="IaaC/aws/lambda/api-func-template.tfvars"
tfv_dest="${api_dir}/${NAME_LOWER}-api.tfvars"
deployer_dir="IaaC/aws/lambda/lambda_deployer"

# 1) Scaffold and build the Lambda handler
mkdir -p "$code_dir"
cp "$template_dir/Makefile" "$code_dir/Makefile"
cp "$template_dir/template_handler.go" "$code_dir/${NAME_LOWER}_handler.go"

pushd "$code_dir" > /dev/null
make clean || true
make
ZIP_PATH=$(find build -maxdepth 1 -type f -name '*.zip' | head -n1)
if [ -z "$ZIP_PATH" ]; then
  echo "Error: build ZIP not found in $code_dir/build" >&2
  exit 1
fi
popd > /dev/null

# 2) Generate Terraform variable file
echo "Generating Terraform variables for ${NAME_LOWER}-api..."
mkdir -p "$api_dir"
sed \
  -e "s|^lambda_function_name.*|lambda_function_name  = \"${NAME_LOWER}-api\"|" \
  -e "s|^lambda_zip_path.*|lambda_zip_path       = \"$(realpath "$code_dir/$ZIP_PATH")\"|" \
  -e "s|^api_name.*|api_name              = \"${NAME_LOWER}-api\"|" \
  -e "s|^api_resource_path.*|api_resource_path     = \"${NAME_LOWER}-api\"|" \
  "$tfv_template" > "$tfv_dest"

# 3) Deploy with Terraform using a fresh workspace
pushd "$deployer_dir" > /dev/null
terraform init

WORKSPACE="${NAME_LOWER}-api"
# Recreate the workspace to clear any stale state
if terraform workspace list | grep -q "${WORKSPACE}"; then
  terraform workspace select default
  terraform workspace delete -force "${WORKSPACE}"
fi
terraform workspace new "${WORKSPACE}"
terraform workspace select "${WORKSPACE}"

terraform apply -var-file="../${NAME_LOWER}-api/${NAME_LOWER}-api.tfvars" -auto-approve

# Capture the outputs
DEFAULT_URL=$(terraform output -raw invoke_url)
CUSTOM_URL=$(terraform output -raw custom_domain_invoke_url)
popd > /dev/null

# 4) Generate curl commands script
curl_script="${api_dir}/curl-cmds.sh"
cat > "$curl_script" <<EOF
#!/usr/bin/env bash
# Invoke URLs for ${NAME_LOWER}-api

# GET via default API Gateway
echo "GET Default: ${DEFAULT_URL}" \
  && curl -s -o /dev/null -w "%{http_code}\n" "${DEFAULT_URL}"

# GET via custom domain
echo "GET Custom: ${CUSTOM_URL}" \
  && curl -s -o /dev/null -w "%{http_code}\n" "${CUSTOM_URL}"

# POST via default API Gateway
echo "POST Default: ${DEFAULT_URL}" \
  && curl -s -o /dev/null -w "%{http_code}\n" -X POST "${DEFAULT_URL}" -H "Content-Type: application/json" -d '{}'

# POST via custom domain
echo "POST Custom: ${CUSTOM_URL}" \
  && curl -s -o /dev/null -w "%{http_code}\n" -X POST "${CUSTOM_URL}" -H "Content-Type: application/json" -d '{}'
EOF
chmod +x "$curl_script"

echo "Deployment of ${NAME_LOWER}-api complete! Curl commands saved to $curl_script"
