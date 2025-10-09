#!/bin/sh
set -euo pipefail

echo "--- Running tflint on all examples"

EXAMPLES="basic complete existing-vpc scheduled-scaling spot-instances"
EXIT_CODE=0

for example in $EXAMPLES; do
  echo "+++ Running tflint on example: ${example}"
  cd "examples/${example}"

  echo "Initializing tflint..."
  if ! tflint --init; then
    echo "^^^ +++"
    echo "❌ tflint init failed for ${example}"
    EXIT_CODE=1
    cd ../..
    continue
  fi

  echo "Running tflint..."
  if ! tflint; then
    echo "^^^ +++"
    echo "❌ tflint failed for ${example}"
    EXIT_CODE=1
  else
    echo "✅ Example ${example} passed tflint"
  fi

  cd ../..
done

if [ $EXIT_CODE -ne 0 ]; then
  echo "--- :x: One or more examples failed tflint"
  exit 1
fi

echo "--- :white_check_mark: All examples passed tflint"
