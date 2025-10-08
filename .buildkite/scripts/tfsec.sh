#!/bin/sh
set -eu

echo "Running tfsec security scan..."
tfsec .

echo "✅ Security scan passed"
exit 0
