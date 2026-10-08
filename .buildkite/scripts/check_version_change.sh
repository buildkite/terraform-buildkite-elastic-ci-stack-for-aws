#!/usr/bin/bash
set -euo pipefail

# Detect if the cloudformation_stack_version has changed since main.
# This runs on both PRs and direct pushes (e.g. Renovate commits), so AMI
# mappings are always kept in sync with the stack version.
git fetch --depth=1 origin main >&2

if git diff origin/main...HEAD -- locals.tf | grep -q 'cloudformation_stack_version'; then
  echo "cloudformation_stack_version changed" >&2

  # update_amis.sh only reads the latest template, so it can't update AMIs for
  # an older major version (e.g. a final v6 release after v7). Those mappings
  # have to be generated manually from the versioned template.
  locals_tf=$(<locals.tf)
  latest_template=$(curl -fsSL https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml)
  [[ $locals_tf =~ cloudformation_stack_version[[:space:]]*=[[:space:]]*\"v([0-9]+)\. ]]
  tf_major=${BASH_REMATCH[1]}
  [[ $latest_template =~ v([0-9]+)\.[0-9]+\.[0-9]+ ]]
  latest_major=${BASH_REMATCH[1]}

  if (( tf_major < latest_major )); then
    echo "Stack v${tf_major} is older than latest v${latest_major}, skipping AMI update. Generate mappings from the versioned template instead." >&2
    exit 0
  fi

  echo "Uploading AMI update pipeline step..." >&2

# TODO: Create a Docker image with git installed to avoid the apk add step entirely, but for now let's just use this image and iterate
# Taking a look at the history of the terraform image, this has always been Alpine based, so shouldn't run into any issues with this, but a Dockerfile would be better, but blocked on this currently.
# I've added some guardrails to ensure if the BASE changes, this will fail loudly in the meantime.

  cat <<EOF | buildkite-agent pipeline upload
steps:
  - label: "Update AMI Mappings"
    plugins:
      - aws-assume-role-with-web-identity#v1.8.0:
          role-arn: arn:aws:iam::445615400570:role/pipeline-terraform-buildkite-elastic-ci-stack-for-aws-release
          session-tags:
            - organization_slug
            - organization_id
            - pipeline_slug
            - build_branch
      - aws-ssm#v1.1.0:
          parameters:
            GITHUB_TOKEN: /pipelines/buildkite/terraform-buildkite-elastic-ci-stack-for-aws-release/GITHUB_TOKEN
      - docker#v5.14.0:
          image: hashicorp/terraform:1.16
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
