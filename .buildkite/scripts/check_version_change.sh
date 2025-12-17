#!/usr/bin/bash
set -euo pipefail

if [ ${BUILDKITE_PULL_REQUEST} == "false" ]; then
  echo "Not a pull request, skipping version change check." >&2
  exit 0
fi

if git diff origin/main...HEAD -- locals.tf | grep -q 'cloudformation_stack_version'; then
  echo "cloudformation_stack_version changed, uploading AMI update pipeline step..." >&2

  cat <<EOF | buildkite-agent pipeline upload
steps:
  - label: "Update AMI Mappings"
    plugins:
      - aws-assume-role-with-web-identity#v1.4.0:
          role-arn: arn:aws:iam::445615400570:role/pipeline-terraform-buildkite-elastic-ci-stack-for-aws-release
          session-tags:
            - organization_slug
            - organization_id
            - pipeline_slug
            - build_branch
      - aws-ssm#v1.1.0:
          parameters:
            GITHUB_TOKEN: /pipelines/buildkite/terraform-buildkite-elastic-ci-stack-for-aws-release/GITHUB_TOKEN
      - docker#v5.13.0:
          image: hashicorp/terraform:1.13
          workdir: "/workdir"
          entrypoint: "/bin/sh"
          command: ["-c", "apk add --no-cache bash curl git yq jq && bash .buildkite/scripts/update_amis.sh"]
          environment:
            - GITHUB_TOKEN
            - BUILDKITE_BRANCH
            - BUILDKITE_PULL_REQUEST
    agents:
      queue: "oss-deploy"
EOF
else
  echo "cloudformation_stack_version unchanged, skipping AMI update" >&2
fi
