mock_provider "aws" {
  mock_data "aws_region" {
    override_during = plan
    defaults = {
      id     = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    override_during = plan
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_partition" {
    override_during = plan
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_availability_zones" {
    override_during = plan
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}

mock_provider "archive" {}

mock_provider "random" {
  mock_resource "random_id" {
    override_during = plan
    defaults = {
      hex = "01234567"
    }
  }
}

run "passes_seed_bucket_to_linux_user_data" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = true
    git_mirror_seed_bucket                     = "test-seed-bucket"
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.agent_launch_template.user_data), "BUILDKITE_GIT_MIRROR_SEED_BUCKET=\"test-seed-bucket\"")
    error_message = "The Linux user data should pass the seed bucket to the agent install script."
  }
}

run "clears_seed_bucket_in_user_data_when_git_mirrors_are_disabled" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = false
    git_mirror_seed_bucket                     = "test-seed-bucket"
  }

  assert {
    condition     = strcontains(base64decode(aws_launch_template.agent_launch_template.user_data), "BUILDKITE_GIT_MIRROR_SEED_BUCKET=\"\"")
    error_message = "The seed bucket should be empty in user data when git mirrors are disabled."
  }
}

run "grants_seed_bucket_access_when_bucket_is_set" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = true
    git_mirror_seed_bucket                     = "test-seed-bucket"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "arn:aws:s3:::test-seed-bucket/git-mirror-seeds/*")
    error_message = "The instance role should be allowed to read seed archives under the git-mirror-seeds/ prefix."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "GitMirrorSeedBucketList")
    error_message = "The instance role should be allowed to list the seed bucket."
  }
}

run "omits_seed_bucket_access_when_git_mirrors_are_disabled" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = false
    git_mirror_seed_bucket                     = "test-seed-bucket"
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "GitMirrorSeedBucketRead")
    error_message = "The instance role should not get seed bucket access when git mirrors are disabled."
  }
}

run "omits_seed_bucket_access_on_windows" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = true
    git_mirror_seed_bucket                     = "test-seed-bucket"
    instance_operating_system                  = "windows"
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "GitMirrorSeedBucketRead")
    error_message = "Seeding runs on Linux only, so Windows stacks should not get seed bucket access."
  }
}

run "omits_seed_bucket_access_when_bucket_is_unset" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    secrets_bucket                             = "test-secrets-bucket"
    buildkite_agent_enable_git_mirrors         = true
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "GitMirrorSeedBucketRead")
    error_message = "The instance role should not get seed bucket access when no seed bucket is set."
  }
}
