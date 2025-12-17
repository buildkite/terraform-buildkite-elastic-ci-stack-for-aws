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
REMOTE_URL="https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws.git"

setup_auth() {
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "Error: GITHUB_TOKEN not set; required for git push and PR comments" >&2
    exit 1
  fi

  REMOTE_URL="https://x-access-token:${GITHUB_TOKEN}@github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws.git"
  echo "Using HTTPS with token for git operations" >&2
}

setup_auth

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
  # Strip whitespace/newlines to avoid contaminating refspec
  branch=$(printf "%s" "$branch" | tr -d '[:space:]')

  if ! git symbolic-ref -q HEAD > /dev/null; then
    echo "In detached HEAD state, checking out branch: $branch" >&2
    git checkout -B "$branch" >&2
  fi

  echo "$branch"
}

commit_and_push() {
  local branch="$1"

  git config user.name "buildkite-systems"
  git config user.email "dev@buildkite.com"

  git add "$LOCALS_FILE"
  git commit -m "Update AMI mappings to CloudFormation version $(get_cloudformation_version)"

  if ! git push "$REMOTE_URL" "HEAD:${branch}"; then
    echo "Error: git push failed. Check token permissions and network/SSH configuration." >&2
    exit 1
  fi

  echo "Pushed changes to branch $branch" >&2
}

post_pr_comment() {
  local message="$1"

  if [[ "${BUILDKITE_PULL_REQUEST:-false}" == "false" ]]; then
    echo "No pull request context; skipping PR comment." >&2
    return
  fi

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    echo "GITHUB_TOKEN not set; cannot post PR comment." >&2
    return
  fi

  local pr_number="$BUILDKITE_PULL_REQUEST"
  local api_url="https://api.github.com/repos/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/issues/${pr_number}/comments"

  echo "Posting PR comment to #${pr_number}" >&2
  curl -sS -X POST \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -d "$(jq -nc --arg body "$message" '{body: $body}')" \
    "$api_url" >/dev/null
}

process_git_changes() {
  show_git_changes

  if ! git diff --quiet "$LOCALS_FILE"; then
    run_terraform_fmt
    local branch
    branch=$(ensure_on_branch)
    commit_and_push "$branch"
    post_pr_comment "Updated AMI mappings to CloudFormation version $(get_cloudformation_version). Check changes for the Elastic CI Stack to ensure that there's no other required changes before merging, such as new required input configuration/variables used by cloud init."
  else
    echo "No changes detected in $LOCALS_FILE" >&2
  fi
}

update_ami_mappings() {
  local version="$1"
  echo "Versions match ($version). Checking if AMI mappings need update..." >&2

  local yaml_content
  yaml_content=$(curl -fsSL "$CLOUDFORMATION_TEMPLATE_URL")

  local temp_mapping
  temp_mapping=$(mktemp)

  echo "  buildkite_ami_mapping = {" > "$temp_mapping"

  # Use yq to parse YAML reliably, then format with awk for padding
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
    # TF version is greater than CF version; wait for CF to catch up
    while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
      echo "TF version $tf_version is greater than CF version $cf_version; retrying in $RETRY_INTERVAL_IN_SECONDS seconds..." >&2
      sleep "$RETRY_INTERVAL_IN_SECONDS"
      RETRY_COUNT=$((RETRY_COUNT + 1))
      cf_version=$(get_cloudformation_version)
      if [[ "$tf_version" == "$cf_version" ]]; then
        update_ami_mappings "$tf_version"
        exit 0
      fi
    done

    echo "Timed out waiting for CloudFormation version to reach $tf_version after $MAX_RETRIES retries" >&2
    exit 1
  fi
}

main() {
  local tf_version
  local cf_version

  tf_version=$(get_tf_version)
  cf_version=$(get_cloudformation_version)

  check_versions "$tf_version" "$cf_version"
}

main "$@"
