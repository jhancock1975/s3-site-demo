#!/usr/bin/env bash
set -euo pipefail
# Trap errors and report the line number
trap 'echo "Error in ${0} at line ${LINENO}" >&2; exit 1' ERR

if [ $# -ne 1 ]; then
  echo "Usage: $0 <name>"
  exit 1
fi

NAME=$1
# Lowercase name for paths
NAME_LOWER=$(echo "$NAME" | tr '[:upper:]' '[:lower:]')

# Directories
template_dir="lambda/lambda-go-template"
code_dir="lambda/${NAME_LOWER}_handler"
api_dir="IaaC/aws/lambda/${NAME_LOWER}-api"
tfv_template="IaaC/aws/lambda/api-func-template.tfvars"
tfv_dest="${api_dir}/${NAME_LOWER}-api.tfvars"
deployer_dir="IaaC/aws/lambda/lambda_deployer"

# 1) Copy code template and build
mkdir -p "$code_dir"
cp "${template_dir}/Makefile" "$code_dir/Makefile"
cp "${template_dir}/template_handler.go" "$code_dir/${NAME_LOWER}_handler.go"

pushd "$code_dir" > /dev/null
make clean || true
make
# find the generated ZIP
ZIP_PATH=$(find build -maxdepth 1 -type f -name '*.zip' | head -n1)
if [ -z "$ZIP_PATH" ]; then
  echo "Error: build ZIP not found in $code_dir/build" >&2
  exit 1
fi
popd > /dev/null

# 2) Create API tfvars
echo "Creating Terraform variables for ${NAME_LOWER}-api..."
mkdir -p "$api_dir"
# Populate the template into the destination
sed \
  -e "s|^lambda_function_name.*|lambda_function_name  = \"${NAME_LOWER}-api\"|" \
  -e "s|^lambda_zip_path.*|lambda_zip_path       = \"$(realpath "$code_dir/$ZIP_PATH")\"|" \
  -e "s|^api_name.*|api_name              = \"${NAME_LOWER}-api\"|" \
  -e "s|^api_resource_path.*|api_resource_path     = \"${NAME_LOWER}-api\"|" \
  "$tfv_template" > "$tfv_dest"

# 3) Deploy with Terraform
pushd "$deployer_dir" > /dev/null
terraform init
# Use a separate workspace per function to isolate state and avoid resource collisions
WORKSPACE="${NAME_LOWER}-api"
if ! terraform workspace list | grep -q "${WORKSPACE}"; then
  terraform workspace new "${WORKSPACE}"
else
  terraform workspace select "${WORKSPACE}"
fi
terraform apply -var-file="../${NAME_LOWER}-api/${NAME_LOWER}-api.tfvars" -auto-approve

# Capture the invoke URLs from Terraform outputs
DEFAULT_URL=$(terraform output -raw invoke_url)
CUSTOM_URL=$(terraform output -raw custom_domain_invoke_url)
popd > /dev/null

# 4) Write curl commands for GET and POST to a script for later use
curl_script="${api_dir}/curl-cmds.sh"
cat > "$curl_script" <<EOF
#!/usr/bin/env bash
# Invoke URLs for ${NAME_LOWER}-api

# GET Default API Gateway URL
curl -v "${DEFAULT_URL}"

# GET Custom Domain URL
curl -v "${CUSTOM_URL}"

# POST Default API Gateway URL
curl -v -X POST "${DEFAULT_URL}" -H "Content-Type: application/json" -d '{}'

# POST Custom Domain URL
curl -v -X POST "${CUSTOM_URL}" -H "Content-Type: application/json" -d '{}'
EOF
chmod +x "$curl_script"

echo "Deployment of ${NAME_LOWER}-api complete! Curl commands saved to $curl_script"
