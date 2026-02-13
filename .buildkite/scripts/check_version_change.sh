#!/usr/bin/bash
set -euo pipefail

if [ ${BUILDKITE_PULL_REQUEST} == "false" ]; then
  echo "Not a pull request, skipping version change check." >&2
  exit 0
fi

git fetch --depth=1 origin main >&2

if git diff origin/main...HEAD -- locals.tf | grep -q 'cloudformation_stack_version'; then
  echo "cloudformation_stack_version changed, uploading AMI update pipeline step..." >&2


# TODO: Create a Docker image with git installed to avoid the apk add step entirely, but for now let's just use this image and iterate
# Taking a look at the history of the terraform image, this has always been Alpine based, so shouldn't run into any issues with this, but a Dockerfile would be better, but blocked on this currently.
# I've added some guardrails to ensure if the BASE changes, this will fail loudly in the meantime.

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
          image: hashicorp/terraform:1.14
          workdir: "/workdir"
          entrypoint: "/bin/sh"
          command: ["-c", "if command -v apk >/dev/null 2>&1; then apk add --no-cache bash curl git yq jq; else echo 'apk not found: hashicorp/terraform image no longer Alpine; aborting AMI update step' >&2; exit 1; fi; bash .buildkite/scripts/update_amis.sh"]
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
