#!/bin/bash
set -euo pipefail

echo "Initializing Terraform..."
terraform init -backend=false

echo "Validating Terraform configuration..."
terraform validate

echo "Running Terraform tests..."
terraform test

echo "✅ Terraform configuration is valid and tests passed"
exit 0
