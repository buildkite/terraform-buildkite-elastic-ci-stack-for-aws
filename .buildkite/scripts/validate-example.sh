#!/bin/bash
set -euo pipefail

EXAMPLE_DIR=$1

echo "Validating example: ${EXAMPLE_DIR}"

cd "examples/${EXAMPLE_DIR}"

echo "Initializing Terraform..."
terraform init -backend=false

echo "Validating configuration..."
terraform validate

echo "✅ Example ${EXAMPLE_DIR} validated successfully"
