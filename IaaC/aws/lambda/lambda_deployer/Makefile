.PHONY: tf-prepare tf-apply

# Initializes, imports the existing base-path mapping, and then plans/applies
tf-prepare:
	terraform init && \
	if ! terraform state list | grep -q aws_api_gateway_base_path_mapping.mapping; then \
	  terraform import aws_api_gateway_base_path_mapping.mapping api.taptupo.com/ ; \
	fi

tf-apply: tf-prepare
	terraform plan -var-file="../dogs-api/dogs-api.tfvars" && \
	terraform apply -var-file="../dogs-api/dogs-api.tfvars"

