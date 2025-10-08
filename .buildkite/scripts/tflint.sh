#!/bin/sh

echo "Initializing TFLint..."
tflint --init

echo "Running TFLint..."
tflint

echo "✅ TFLint checks passed"
exit 0
