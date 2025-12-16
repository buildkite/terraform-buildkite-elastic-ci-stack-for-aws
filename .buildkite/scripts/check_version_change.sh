#!/usr/bin/bash
set -euo pipefail

if git diff origin/main...HEAD -- locals.tf | grep -q 'cloudformation_stack_version'; then
  echo "cloudformation_stack_version changed, uploading AMI update pipeline step..." >&2

  cat <<EOF | buildkite-agent pipeline upload
steps:
  - label: "Update AMI Mappings"
    plugins:
      - docker#v5.13.0:
          image: hashicorp/terraform:1.13
          workdir: "/workdir"
          entrypoint: "/bin/sh"
          command: ["-c", "apk add --no-cache bash curl git openssh && bash .buildkite/scripts/check_ami_version_match.sh"]
          environment:
            - DEPLOY_KEY
            - BUILDKITE_BRANCH
    secrets:
        DEPLOY_KEY: ES_FOR_TF_PUB_KEY
    agents:
      queue: "oss-deploy"
EOF
else
  echo "cloudformation_stack_version unchanged, skipping AMI update" >&2
  cat <<EOF | buildkite-agent pipeline upload
steps:
  - label: "Update AMI Mappings"
    plugins:
      - docker#v5.13.0:
          image: hashicorp/terraform:1.13
          workdir: "/workdir"
          entrypoint: "/bin/sh"
          command: ["-c", "apk add --no-cache bash curl git openssh && bash .buildkite/scripts/check_ami_version_match.sh"]
          environment:
            - DEPLOY_KEY
            - BUILDKITE_BRANCH
    secrets:
        DEPLOY_KEY: ES_FOR_TF_PUB_KEY
    agents:
      queue: "oss-deploy"
EOF
fi
