#!/bin/sh
set -eu

echo "Checking generated Terraform documentation..."
terraform-docs --version

if ! terraform-docs markdown table . --output-file README.md --output-mode inject --output-check; then
  echo "Documentation check failed. To regenerate the Terraform reference, run:"
  echo "terraform-docs markdown table . --output-file README.md --output-mode inject"
  exit 1
fi

echo "Terraform documentation is up to date"
