#!/usr/bin/env bash
set -euo pipefail

# This script will essentially do the following:
# 1. Read the version of the CloudFormation stack from locals.tf
# 2. Fetch the latest CloudFormation template from S3
# 3. Extract the version from the CloudFormation template
# 4. Compare the two versions
# 5. If they match, we're going to update the AMI's in locals.tf
# 6. If they don't match, wait and retry until they do (or fail if TF version is less than CF version or we hit a timeout of 1 hour)

LOCALS_FILE="${1:-locals.tf}"
CLOUDFORMATION_TEMPLATE_URL="https://s3.amazonaws.com/buildkite-aws-stack/latest/aws-stack.yml"
RETRY_INTERVAL_IN_SECONDS=600
MAX_RETRIES=6 # 1 hour seems rational because the CI for Packer takes a while
RETRY_COUNT=0

setup_ssh() {
  if [[ -z "${DEPLOY_KEY:-}" ]]; then
    echo "Error: DEPLOY_KEY not set" >&2
    exit 1
  fi

  echo "Setting up SSH for git operations..." >&2
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  echo "$DEPLOY_KEY" > ~/.ssh/deploy_key
  chmod 600 ~/.ssh/deploy_key

  cat > ~/.ssh/config <<EOF
Host github.com
  HostName github.com
  IdentityFile ~/.ssh/deploy_key
  IdentitiesOnly yes
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  chmod 600 ~/.ssh/config
}

setup_ssh

get_tf_version() {
  local version
  version=$(grep -E 'cloudformation_stack_version\s*=\s*"v?[0-9]+\.[0-9]+\.[0-9]+"' "$LOCALS_FILE" | sed -E 's/.*"(v?[0-9]+\.[0-9]+\.[0-9]+)".*/\1/')

  if [[ -z "$version" ]]; then
    echo "Unable to extract version from $LOCALS_FILE" >&2
    exit 1
  fi

  echo "$version"
}

get_cloudformation_version() {
  local version
  version=$(curl -fsSL "$CLOUDFORMATION_TEMPLATE_URL" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -n1)

  if [[ -z "$version" ]]; then
    echo "Unable to extract version from CloudFormation Template" >&2
    exit 1
  fi

  echo "$version"
}

show_git_changes() {
  echo "Git status:" >&2
  git status >&2

  echo "" >&2
  echo "Changes to $LOCALS_FILE:" >&2
  git diff "$LOCALS_FILE" >&2
}

run_terraform_fmt() {
  echo "Running terraform fmt on $LOCALS_FILE..." >&2
  terraform fmt "$LOCALS_FILE"
}

ensure_on_branch() {
  local branch="${BUILDKITE_BRANCH:-main}"

  if ! git symbolic-ref -q HEAD > /dev/null; then
    echo "In detached HEAD state, checking out branch: $branch" >&2
    git checkout -B "$branch"
  fi

  echo "$branch"
}

commit_and_push() {
  local branch="$1"

  git config user.name "buildkite-systems"
  git config user.email "dev@buildkite.com"

  git add "$LOCALS_FILE"
  git commit -m "Update AMI mappings to CloudFormation version $(get_cloudformation_version)"

  if ! git push "git@github.com:buildkite/terraform-buildkite-elastic-ci-stack-for-aws.git" "HEAD:${branch}"; then
    echo "Error: git push failed. Check deploy key permissions and SSH configuration." >&2
    exit 1
  fi

  echo "Pushed changes to branch $branch" >&2
}

process_git_changes() {
  show_git_changes

  if ! git diff --quiet "$LOCALS_FILE"; then
    run_terraform_fmt
    local branch
    branch=$(ensure_on_branch)
    commit_and_push "$branch"
  else
    echo "No changes detected in $LOCALS_FILE" >&2
  fi
}

update_ami_mappings() {
  local version="$1"
  echo "Versions match ($version). Checking if AMI mappings need update..." >&2

  # Fetch the CloudFormation template and extract AMI section
  local yaml_content
  yaml_content=$(curl -fsSL "$CLOUDFORMATION_TEMPLATE_URL")

  local temp_mapping
  temp_mapping=$(mktemp)

  echo "  buildkite_ami_mapping = {" > "$temp_mapping"

  echo "$yaml_content" | yq -r '.Mappings.AWSRegion2AMI | to_entries[] | "\(.key)|\(.value.linuxamd64)|\(.value.linuxarm64)|\(.value.windows)"' | \
    awk -F'|' '{printf "    %-28s = { linuxamd64 = \"%-21s\", linuxarm64 = \"%-21s\", windows = \"%-21s\" }\n", $1, $2, $3, $4}' >> "$temp_mapping"

  echo "    cloudformation_stack_version = \"$version\"" >> "$temp_mapping"
  echo "  }" >> "$temp_mapping"

  local current_mapping
  current_mapping=$(awk '/buildkite_ami_mapping = \{/,/^  \}$/' "$LOCALS_FILE")

  local new_mapping
  new_mapping=$(cat "$temp_mapping")

  if [[ "$current_mapping" == "$new_mapping" ]]; then
    echo "AMI mappings are already up to date. No changes needed." >&2
    rm -f "$temp_mapping"
    exit 0
  fi

  echo "AMI mappings differ, updating..." >&2

  awk '
    /buildkite_ami_mapping = \{/ {
      while ((getline line < "'"$temp_mapping"'") > 0) {
        print line
      }
      close("'"$temp_mapping"'")
      in_mapping=1
      next
    }
    in_mapping {
      if (/^  \}$/) {
        in_mapping=0
      }
      next
    }
    { print }
  ' "$LOCALS_FILE" > "$LOCALS_FILE.tmp"

  mv "$LOCALS_FILE.tmp" "$LOCALS_FILE"
  rm -f "$temp_mapping"
  echo "AMI mappings updated successfully" >&2

  process_git_changes
}

check_versions() {
  local tf_version="$1"
  local cf_version="$2"

  if [[ "$tf_version" == "$cf_version" ]]; then
    update_ami_mappings "$tf_version"
    exit 0
  elif [[ "$tf_version" < "$cf_version" ]]; then
    echo "Terraform version $tf_version is less than CloudFormation version $cf_version, this needs to be bumped to the latest CloudFormation version" >&2
    exit 1
  else
    # TF Version is greater than the CloudFormation version, so we'll keep checking until the CloudFormation Template is published
    return 1
  fi
}

while true; do
  TF_VERSION=$(get_tf_version)
  CLOUDFORMATION_VERSION=$(get_cloudformation_version)

  if check_versions "$TF_VERSION" "$CLOUDFORMATION_VERSION"; then
    break
  fi

  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "Exceeded maximum retries ($MAX_RETRIES). Exiting, give it some time and retry this job." >&2
    exit 1
  fi

  echo "Waiting for new CloudFormation Template to be published, TF_VERSION is $TF_VERSION while CloudFormation version is $CLOUDFORMATION_VERSION. Retrying in 10 minutes..." >&2
  sleep "$RETRY_INTERVAL_IN_SECONDS"
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
