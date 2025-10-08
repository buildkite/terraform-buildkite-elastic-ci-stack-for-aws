#!/bin/bash
set -euo pipefail

echo "Validating example configurations..."

for example in examples/*/; do
  if [ -d "$example" ]; then
    echo ""
    echo "🔍 Validating $example"
    (
      cd "$example"
      terraform init -backend=false
      terraform validate
    )
    echo "✅ $example is valid"
  fi
done

echo ""
echo "✅ All examples validated successfully"
exit 0
