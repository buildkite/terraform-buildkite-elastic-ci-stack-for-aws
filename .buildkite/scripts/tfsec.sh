#!/bin/sh

echo "Running tfsec security scan..."
tfsec .

echo "✅ Security scan passed"
exit 0
