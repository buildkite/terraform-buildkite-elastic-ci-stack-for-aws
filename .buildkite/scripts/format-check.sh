#!/bin/bash
set -euo pipefail

echo "Checking Terraform formatting..."

if ! terraform fmt -check -recursive; then
  echo "❌ Terraform files are not formatted."
  echo "Run: terraform fmt -recursive"
  exit 1
fi

echo "✅ All Terraform files are properly formatted"
exit 0
