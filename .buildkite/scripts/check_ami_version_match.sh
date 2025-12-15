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
  git status

  echo "" >&2
  echo "Changes to $LOCALS_FILE:" >&2
  git diff "$LOCALS_FILE"
  git add "$LOCALS_FILE"
  git commit -m "Update AMI mappings to CloudFormation version $(get_tf_version)" || {
    echo "No changes to commit" >&2
  }
  git push || {
    echo "No changes to push" >&2
  }
}

update_ami_mappings() {
  local version="$1"
  echo "Versions match ($version). Updating AMI mappings..." >&2

  # Fetch the CloudFormation template and extract AMI section
  local ami_lines
  ami_lines=$(curl -fsSL "$CLOUDFORMATION_TEMPLATE_URL" | awk '/AWSRegion2AMI:/,/^[^ ]/' | grep -E '^\s+[a-z0-9-]+\s*:')

  # Create temp file with new mapping
  local temp_mapping
  temp_mapping=$(mktemp)

  echo "  buildkite_ami_mapping = {" > "$temp_mapping"

  # Parse each line and convert to Terraform format
  while IFS= read -r line; do
    if [[ "$line" =~ ([a-z0-9-]+)[[:space:]]*:[[:space:]]*\{[[:space:]]*linuxamd64:[[:space:]]*(ami-[a-f0-9]+),[[:space:]]*linuxarm64:[[:space:]]*(ami-[a-f0-9]+),[[:space:]]*windows:[[:space:]]*(ami-[a-f0-9]+) ]]; then
      region="${BASH_REMATCH[1]}"
      amd64="${BASH_REMATCH[2]}"
      arm64="${BASH_REMATCH[3]}"
      windows="${BASH_REMATCH[4]}"
      printf "    %-28s = { linuxamd64 = \"%-21s, linuxarm64 = \"%-21s, windows = \"%-21s }\n" \
        "$region" "$amd64\"" "$arm64\"" "$windows\"" >> "$temp_mapping"
    fi
  done <<< "$ami_lines"

  echo "    cloudformation_stack_version = \"$version\"" >> "$temp_mapping"
  echo "  }" >> "$temp_mapping"

  # Replace in locals.tf
  awk '
    BEGIN { in_mapping=0 }
    /buildkite_ami_mapping = {/ {
      in_mapping=1
      while ((getline line < "'"$temp_mapping"'") > 0) {
        print line
      }
      close("'"$temp_mapping"'")
      next
    }
    in_mapping && /^  }/ { in_mapping=0; next }
    !in_mapping { print }
  ' "$LOCALS_FILE" > "$LOCALS_FILE.tmp"

  mv "$LOCALS_FILE.tmp" "$LOCALS_FILE"
  rm -f "$temp_mapping"
  echo "AMI mappings updated successfully" >&2

  show_git_changes
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

  # If we get here, TF version is ahead of CF version
  if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
    echo "Exceeded maximum retries ($MAX_RETRIES). Exiting, give it some time and retry this job." >&2
    exit 1
  fi

  echo "Waiting for new CloudFormation Template to be published, TF_VERSION is $TF_VERSION while CloudFormation version is $CLOUDFORMATION_VERSION. Retrying in 10 minutes..." >&2
  sleep "$RETRY_INTERVAL_IN_SECONDS"
  RETRY_COUNT=$((RETRY_COUNT + 1))
done
