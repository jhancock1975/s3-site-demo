# Makefile to compile and package the Go Lambda, with module initialization

# Configuration
BUILD_DIR := build
BIN_NAME   := bootstrap
ZIP_NAME   := dogs-api.zip
MODULE_NAME ?= dogs-api

GOOS   := linux
GOARCH := amd64

# Find the Go source file
SRC := $(wildcard *.go)

.PHONY: all compile package clean

# Default target: compile binary and package ZIP
all: package

# Compile the Go binary for Linux/AMD64, initializing modules if needed
compile: $(BUILD_DIR)/$(BIN_NAME)

$(BUILD_DIR)/$(BIN_NAME): $(SRC) | $(BUILD_DIR)
	@if [ ! -f go.mod ]; then \
		go mod init $(MODULE_NAME); \
	fi; \
	go mod tidy; \
	GOOS=$(GOOS) GOARCH=$(GOARCH) go build -o $@ $(SRC)

# Package the binary into a ZIP ready for Lambda
package: compile
	zip -j $(BUILD_DIR)/$(ZIP_NAME) $(BUILD_DIR)/$(BIN_NAME)

# Ensure build directory exists
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Clean artifacts including module files and build outputs
clean:
	rm -rf $(BUILD_DIR) go.mod go.sum
