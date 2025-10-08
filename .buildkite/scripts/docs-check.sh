#!/bin/bash
set -euo pipefail

# Install git if not present (needed for git diff)
if ! command -v git &> /dev/null; then
  apk add --no-cache git
fi

echo "Generating documentation..."

# Create a backup to compare
cp README.md README.md.bak

terraform-docs markdown table . --output-file README.md --output-mode inject

echo "Checking for documentation changes..."
if ! diff -q README.md.bak README.md > /dev/null 2>&1; then
  echo "❌ Documentation is out of date."
  echo "Run: terraform-docs markdown table . --output-file README.md --output-mode inject"
  rm README.md.bak
  exit 1
fi

rm README.md.bak
echo "✅ Documentation is up to date"
exit 0
