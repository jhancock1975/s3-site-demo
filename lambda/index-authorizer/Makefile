.PHONY: all build clean deploy

# Variables
BINARY_NAME=main
OUTPUT_ZIP=deployment.zip
GOOS=linux
GOARCH=amd64

all: clean build package

# Build the binary for AWS Lambda (Linux)
build:
    GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $(BINARY_NAME) main.go
    @echo "Binary built successfully."

# Package the binary into a ZIP file for Lambda deployment
package: build
    zip $(OUTPUT_ZIP) $(BINARY_NAME)
    @echo "Deployment package created: $(OUTPUT_ZIP)"

# Clean build artifacts
clean:
    @echo "Cleaning up..."
    rm -f $(BINARY_NAME) $(OUTPUT_ZIP)

# Deploy to AWS Lambda (if you want to add this functionality)
deploy: package
    @echo "Deploying to AWS Lambda..."
    # aws lambda update-function-code --function-name index-authorizer --zip-file fileb://$(OUTPUT_ZIP)