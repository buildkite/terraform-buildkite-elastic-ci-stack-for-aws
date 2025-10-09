#!/bin/sh
set -euo pipefail

echo "--- Running terraform validate on all examples"

EXAMPLES="basic complete existing-vpc scheduled-scaling spot-instances"
EXIT_CODE=0

for example in $EXAMPLES; do
  echo "+++ Validating example: ${example}"
  cd "examples/${example}"

  echo "Running terraform init..."
  if ! terraform init -backend=false; then
    echo "^^^ +++"
    echo "❌ Terraform init failed for ${example}"
    EXIT_CODE=1
    cd ../..
    continue
  fi

  echo "Running terraform validate..."
  if ! terraform validate; then
    echo "^^^ +++"
    echo "❌ Terraform validation failed for ${example}"
    EXIT_CODE=1
  else
    echo "✅ Example ${example} validated successfully"
  fi

  cd ../..
done

if [ $EXIT_CODE -ne 0 ]; then
  echo "--- :x: One or more examples failed validation"
  exit 1
fi

echo "--- :white_check_mark: All examples passed validation"
