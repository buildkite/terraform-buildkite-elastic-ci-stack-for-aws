#!/bin/sh
set -euo pipefail

echo "--- Running terraform fmt check on all examples"

EXAMPLES="basic complete existing-vpc scheduled-scaling spot-instances"
EXIT_CODE=0

for example in $EXAMPLES; do
  echo "+++ Checking example: ${example}"
  cd "examples/${example}"

  if ! terraform fmt -check -recursive; then
    echo "^^^ +++"
    echo "❌ Terraform files in ${example} are not formatted."
    echo "Run: cd examples/${example} && terraform fmt -recursive"
    EXIT_CODE=1
  else
    echo "✅ Example ${example} is properly formatted"
  fi

  cd ../..
done

if [ $EXIT_CODE -ne 0 ]; then
  echo "--- :x: One or more examples failed format check"
  exit 1
fi

echo "--- :white_check_mark: All examples passed format check"
