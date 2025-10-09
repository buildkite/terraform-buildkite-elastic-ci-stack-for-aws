#!/bin/bash
set -euo pipefail

# Install git if not present (needed for git diff)
if ! command -v git &> /dev/null; then
  apk add --no-cache git
fi

echo "Generating documentation..."
echo "Current commit: $(git rev-parse HEAD 2>/dev/null || echo 'not a git repo')"
echo "README.md before generation:"
md5sum README.md || true

# Create a backup to compare
cp README.md README.md.bak

terraform-docs markdown table . --output-file README.md --output-mode inject

echo "README.md after generation:"
md5sum README.md || true

echo "Checking for documentation changes..."
if ! diff -q README.md.bak README.md > /dev/null 2>&1; then
  echo "❌ Documentation is out of date."
  echo "Run: terraform-docs markdown table . --output-file README.md --output-mode inject"
  echo ""
  echo "Differences found:"
  diff -u README.md.bak README.md | head -100 || true
  rm README.md.bak
  exit 1
fi

rm README.md.bak
echo "✅ Documentation is up to date"
exit 0
