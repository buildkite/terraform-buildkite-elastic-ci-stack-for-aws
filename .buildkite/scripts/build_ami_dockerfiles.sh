#!/usr/bin/env bash
set -euo pipefail

ACCOUNT_ID="445615400570"
REGION="us-east-1"
REPO_NAME="terraform-buildkite-elastic-ci-stack-for-aws-ami-updater"
IMAGE_TAG="latest"

ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
IMAGE_URI="${ECR_REGISTRY}/${REPO_NAME}:${IMAGE_TAG}"

echo "--- :docker: Building Docker image"
docker build -t "${REPO_NAME}:${IMAGE_TAG}" .buildkite/

echo "--- :docker: Tagging image for ECR"
docker tag "${REPO_NAME}:${IMAGE_TAG}" "${IMAGE_URI}"

echo "--- :docker: Pushing image to ECR"
docker push "${IMAGE_URI}"

echo "✅ Successfully pushed ${IMAGE_URI}"
