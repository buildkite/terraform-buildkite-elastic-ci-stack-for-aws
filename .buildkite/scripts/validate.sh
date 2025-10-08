#!/bin/bash
set -euo pipefail

echo "Initializing Terraform..."
terraform init -backend=false

echo "Validating Terraform configuration..."
terraform validate

echo "✅ Terraform configuration is valid"
exit 0
