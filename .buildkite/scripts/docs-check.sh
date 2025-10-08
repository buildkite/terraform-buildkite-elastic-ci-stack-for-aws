#!/bin/bash
set -euo pipefail

echo "Generating documentation..."
terraform-docs markdown table . --output-file README.md --output-mode inject

echo "Checking for documentation changes..."
if ! git diff --exit-code README.md; then
  echo "❌ Documentation is out of date."
  echo "Run: terraform-docs markdown table . --output-file README.md --output-mode inject"
  exit 1
fi

echo "✅ Documentation is up to date"
exit 0
