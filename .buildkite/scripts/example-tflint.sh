#!/bin/sh
set -euo pipefail

EXAMPLE_DIR="$1"

echo "Running TFLint for example: ${EXAMPLE_DIR}"

cd "examples/${EXAMPLE_DIR}"

echo "Initializing TFLint..."
tflint --init

echo "Running TFLint..."
tflint

echo "✅ TFLint checks passed for ${EXAMPLE_DIR}"
exit 0
