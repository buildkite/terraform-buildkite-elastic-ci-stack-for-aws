#!/bin/sh
set -euo pipefail

EXAMPLE_DIR="$1"

echo "Checking Terraform formatting for example: ${EXAMPLE_DIR}"

cd "examples/${EXAMPLE_DIR}"

if ! terraform fmt -check -recursive; then
  echo "❌ Terraform files in ${EXAMPLE_DIR} are not formatted."
  echo "Run: cd examples/${EXAMPLE_DIR} && terraform fmt -recursive"
  exit 1
fi

echo "✅ Example ${EXAMPLE_DIR} is properly formatted"
exit 0
