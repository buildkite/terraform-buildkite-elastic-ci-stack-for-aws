#!/usr/bin/bash
set -euo pipefail

if git diff origin/main...HEAD -- locals.tf | grep -q 'cloudformation_stack_version'; then
  echo "cloudformation_stack_version changed, uploading AMI update pipeline step..." >&2

  cat <<EOF | buildkite-agent pipeline upload
steps:
  - label: ":robot: Update AMI Mappings"
    plugins:
      - aws-ssm#v1.1.0:
          parameters:
            DEPLOY_KEY: /pipelines/buildkite/terraform-buildkite-elastic-ci-stack-for-aws-release/DEPLOY_KEY
      - docker#v5.13.0:
          image: hashicorp/terraform:1.13
          workdir: "/workdir"
          entrypoint: "/bin/sh"
          command: ["-c", "apk add --no-cache bash curl git openssh && bash .buildkite/scripts/check_ami_version_match.sh"]
          environment:
            - DEPLOY_KEY
            - BUILDKITE_BRANCH
            - BUILDKITE_PULL_REQUEST
            - BUILDKITE_PULL_REQUEST_REPO
    agents:
      queue: "oss-deploy"
EOF
else
  echo "cloudformation_stack_version unchanged, skipping AMI update" >&2
fi
