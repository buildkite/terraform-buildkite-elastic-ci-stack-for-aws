locals {
  # AWS managed policies for container registry access
  ecr_policy_arns = {
    none                  = ""
    readonly              = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    readonly-pullthrough  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    poweruser             = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    poweruser-pullthrough = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    full                  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  }

  # VPC, subnet, and security group creation flags
  create_vpc            = var.create_vpc != null ? var.create_vpc : var.vpc_id == ""
  create_security_group = length(var.security_group_ids) == 0
  use_custom_azs        = var.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.enable_secrets_plugin && var.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.secrets_bucket_encryption
  use_existing_secrets  = var.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.artifacts_bucket != ""

  # The AMI only seeds git mirrors on Linux, and only when mirrors are enabled.
  has_git_mirror_seed_bucket = !local.is_windows && var.buildkite_agent_enable_git_mirrors && var.git_mirror_seed_bucket != ""
  git_mirror_seeds_prefix    = "git-mirror-seeds"

  # Instance role, permissions boundary, and policy settings
  use_custom_iam_role              = var.instance_role_arn != ""
  use_custom_role_name             = var.instance_role_name != ""
  use_custom_instance_profile_name = var.instance_profile_name != ""
  use_permissions_boundary         = var.instance_role_permissions_boundary_arn != ""

  custom_role_name = local.use_custom_iam_role ? element(split("/", var.instance_role_arn), length(split("/", var.instance_role_arn)) - 1) : ""

  use_custom_scaler_lambda_role         = var.scaler_lambda_role_arn != ""
  use_custom_asg_process_suspender_role = var.asg_process_suspender_role_arn != ""
  use_custom_stop_buildkite_agents_role = var.stop_buildkite_agents_role_arn != ""

  # Parse comma-separated role tags into list
  role_tag_list  = compact(split(",", var.instance_role_tags))
  role_tag_count = length(local.role_tag_list)

  # managed_policy_arns entries stay keyed by ARN so existing attachments keep
  # their state addresses. managed_policies entries are keyed by the caller's
  # static names, so their ARNs can be unknown until apply.
  instance_managed_policies = merge(
    { for arn in toset(var.managed_policy_arns) : arn => arn },
    var.managed_policies,
  )

  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-068888f71e6ae6ebf", linuxarm64 = "ami-0059156ccaac1af77", windows = "ami-093f230c62f520a62", ubuntu2404amd64 = "ami-09faabedabad1785b", ubuntu2404arm64 = "ami-02384995278232bb4", windows2025 = "ami-04c58f1c5c5adf221" }
    us-east-2                    = { linuxamd64 = "ami-05fb377986e82fcf2", linuxarm64 = "ami-0ff5e5be1d07096bf", windows = "ami-0b57710bcbddb9e5d", ubuntu2404amd64 = "ami-07c7ac99ad625e64a", ubuntu2404arm64 = "ami-047c3a1efce58aa2c", windows2025 = "ami-0f3b89cccebb2d0ac" }
    us-west-1                    = { linuxamd64 = "ami-064a627913d9238bb", linuxarm64 = "ami-013eea143582a60ec", windows = "ami-085e4f7c69a131451", ubuntu2404amd64 = "ami-0b2526d0771da6d01", ubuntu2404arm64 = "ami-0e95d054af74a2a4a", windows2025 = "ami-0decef7f3d13d4d59" }
    us-west-2                    = { linuxamd64 = "ami-0cd5d2140fb4bb43d", linuxarm64 = "ami-09cb030f993253d95", windows = "ami-0fb3d7f7731155f48", ubuntu2404amd64 = "ami-094a60e25119884b9", ubuntu2404arm64 = "ami-0567d31f196d3fa49", windows2025 = "ami-05650d1a1c99ddd6d" }
    af-south-1                   = { linuxamd64 = "ami-0aaed9475517273e6", linuxarm64 = "ami-021756aa9ac81fa52", windows = "ami-060e16d9da8510bdf", ubuntu2404amd64 = "ami-0fdd4e0cf87dea746", ubuntu2404arm64 = "ami-0ac3b037478a01112", windows2025 = "ami-0b0cf87b2f31cfad8" }
    ap-east-1                    = { linuxamd64 = "ami-00896c468fbdf39dd", linuxarm64 = "ami-005c16db3e77e7d5d", windows = "ami-0ac749518a0c045c9", ubuntu2404amd64 = "ami-05b16c39309031a46", ubuntu2404arm64 = "ami-06ee3896b085ee95c", windows2025 = "ami-04df70468d16920ee" }
    ap-south-1                   = { linuxamd64 = "ami-0cac2b149e4e1c580", linuxarm64 = "ami-05be06d8af3f9ca37", windows = "ami-0d5396d672c9de183", ubuntu2404amd64 = "ami-0778564b77e0ac4c6", ubuntu2404arm64 = "ami-0a467c69713a017b3", windows2025 = "ami-0d84a074f18c1c41a" }
    ap-northeast-2               = { linuxamd64 = "ami-027aaf943ba7780b1", linuxarm64 = "ami-050ae94310ffe1140", windows = "ami-0c1f94bfec1b96cb9", ubuntu2404amd64 = "ami-0557dc7ad31edba2e", ubuntu2404arm64 = "ami-0df85a84aff81a2aa", windows2025 = "ami-0202a24389f712204" }
    ap-northeast-1               = { linuxamd64 = "ami-06548912e0f87495f", linuxarm64 = "ami-0c74094ff87a3cd01", windows = "ami-09bc8777f674a0a1e", ubuntu2404amd64 = "ami-04845c6b851d3ee30", ubuntu2404arm64 = "ami-01c9f9932d6cef9db", windows2025 = "ami-0b7a9059e6702e517" }
    ap-southeast-2               = { linuxamd64 = "ami-0f7fc90e447d1853d", linuxarm64 = "ami-01c082d8e9072cbd6", windows = "ami-0e00f995335cacb2e", ubuntu2404amd64 = "ami-0a65202b46f4b978d", ubuntu2404arm64 = "ami-028bca7325492d241", windows2025 = "ami-0d0f8b7cb75bac732" }
    ap-southeast-1               = { linuxamd64 = "ami-0521f531285957ace", linuxarm64 = "ami-02c02e927f48e3ebb", windows = "ami-034ea6f0bcdb9fef7", ubuntu2404amd64 = "ami-0f7510eca2487bbb9", ubuntu2404arm64 = "ami-058323b59240b9dcc", windows2025 = "ami-0f2e23db20237ba65" }
    ca-central-1                 = { linuxamd64 = "ami-0fa61f0f45b5e412a", linuxarm64 = "ami-06a7d4dc9890b61eb", windows = "ami-0238379c694f79dbd", ubuntu2404amd64 = "ami-064e8632a35414436", ubuntu2404arm64 = "ami-0a79830df77bcbdc6", windows2025 = "ami-0544d0a9a4b914f49" }
    eu-central-1                 = { linuxamd64 = "ami-021da262d7260b2b1", linuxarm64 = "ami-0596a8799bb89ea07", windows = "ami-01298827c53c5cfbe", ubuntu2404amd64 = "ami-05419fa74b6f28d8f", ubuntu2404arm64 = "ami-00e10c0cb14accdc4", windows2025 = "ami-0a737e3a1f0890254" }
    eu-west-1                    = { linuxamd64 = "ami-0a10bed06070cee05", linuxarm64 = "ami-0bb14cc5801784586", windows = "ami-0bb3f17abbbf86d01", ubuntu2404amd64 = "ami-0e33f680686f95cd8", ubuntu2404arm64 = "ami-009691296360b1a19", windows2025 = "ami-050e8d7e705ebd714" }
    eu-west-2                    = { linuxamd64 = "ami-0a852b89880b52853", linuxarm64 = "ami-06d579765302a9118", windows = "ami-0cf3396393a2a239c", ubuntu2404amd64 = "ami-016cdba97107d6171", ubuntu2404arm64 = "ami-0d1a1685d62f0ca42", windows2025 = "ami-00d07e03fc2358bb6" }
    eu-south-1                   = { linuxamd64 = "ami-0ebc0ddb2d1d10bcb", linuxarm64 = "ami-0243a3e9ff59d0002", windows = "ami-005575837df6e9b53", ubuntu2404amd64 = "ami-021bc6512f5b677c1", ubuntu2404arm64 = "ami-05d0a6b3aae64e3da", windows2025 = "ami-0354887417f1cf3bc" }
    eu-west-3                    = { linuxamd64 = "ami-050ecde969a718238", linuxarm64 = "ami-0037dd4a4d7e25627", windows = "ami-0ff6966066d9b3beb", ubuntu2404amd64 = "ami-03475cc99fe0b593b", ubuntu2404arm64 = "ami-06603657fde6e88a6", windows2025 = "ami-0c33fac2ea9cfbc46" }
    eu-north-1                   = { linuxamd64 = "ami-036d5112e6019ca07", linuxarm64 = "ami-031b8ac96a9d6a68d", windows = "ami-04a313d3862acf222", ubuntu2404amd64 = "ami-03f07c6fc636fdfa7", ubuntu2404arm64 = "ami-09d8e24d9c2973f86", windows2025 = "ami-0b9b6be7b4c544572" }
    sa-east-1                    = { linuxamd64 = "ami-073b0d96a1c8cab72", linuxarm64 = "ami-08e01b224c914cd14", windows = "ami-06b7cfd9ad40e22d4", ubuntu2404amd64 = "ami-07f49de48b885037c", ubuntu2404arm64 = "ami-07d15512c898981b8", windows2025 = "ami-07831d7e9c93fe324" }
    cloudformation_stack_version = "v7.15.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.1"
  # Created and updated by the scaler itself, as in the upstream scaler template
  scaler_last_scale_in_parameter = "/buildkite-agent-scaler/${local.stack_name_full}/last-scale-in"
  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM (AWS Graviton) families carry a "g" in the options position, right after
  # the generation digit (e.g. c8gd, m8gn, r8gb, x8g, i8g, hpc7g, g5g, x2gd). a1
  # is the original Graviton1 family and predates this convention, so it has no "g".
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_arm_instance = (
    local.instance_type_family == "a1" ||
    can(regex("^[a-z]+[0-9]+g", local.instance_type_family))
  )

  # Burstable (T series) instances earn and spend CPU credits. The "t" series
  # letter in the first position identifies them (t2, t3, t3a, t4g).
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_burstable_instance = can(regex("^t[0-9]", local.instance_type_family))

  is_windows = var.instance_operating_system == "windows"
  is_ubuntu  = !local.is_windows && var.linux_distribution == "ubuntu2404"
  ami_architecture = local.is_windows ? (var.windows_server_version == "2025" ? "windows2025" : "windows") : (
    local.is_ubuntu ? (local.is_arm_instance ? "ubuntu2404arm64" : "ubuntu2404amd64") : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  )
  selected_ami_id = local.buildkite_ami_mapping[data.aws_region.current.region][local.ami_architecture]

  # Instance naming and timeout settings
  use_default_timeout      = var.instance_creation_timeout == ""
  use_custom_name          = var.instance_name != ""
  has_variable_size        = var.max_size != var.min_size
  enable_scheduled_scaling = var.enable_scheduled_scaling

  # EBS volume type detection and device naming
  use_default_volume_name = var.root_volume_name == ""
  is_gp3_volume           = var.root_volume_type == "gp3"
  supports_iops           = contains(["io1", "io2", "gp3"], var.root_volume_type)

  # Container registry access settings
  enable_ecr             = var.ecr_access_policy != "none"
  enable_ecr_pullthrough = contains(["readonly-pullthrough", "poweruser-pullthrough"], var.ecr_access_policy)

  # Buildkite agent token and parameter store settings
  use_custom_token_path    = var.buildkite_agent_token_parameter_store_path != ""
  token_path_is_arn        = startswith(var.buildkite_agent_token_parameter_store_path, "arn:")
  use_custom_token_kms     = var.buildkite_agent_token_parameter_store_kms_key != ""
  token_kms_key_is_arn     = startswith(var.buildkite_agent_token_parameter_store_kms_key, "arn:")
  create_token_parameter   = var.buildkite_agent_token_parameter_store_path == ""
  enable_graceful_shutdown = var.buildkite_agent_enable_graceful_shutdown

  # KMS key settings for pipeline signature verification
  use_existing_signing_key = var.pipeline_signing_kms_key_id != ""
  create_signing_key       = var.pipeline_signing_kms_key_id == "" && var.pipeline_signing_kms_key_spec != "none"
  has_signing_key          = local.create_signing_key || local.use_existing_signing_key
  signing_key_full_access  = var.pipeline_signing_kms_access == "sign-and-verify"
  signing_key_is_arn       = startswith(var.pipeline_signing_kms_key_id, "arn:")

  # Computed signing key ARN (for use in templates)
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

  # Computed agent token parameter ARN (for IAM policies)
  # A parameter shared from another account is referenced by its full ARN.
  agent_token_parameter_arn = local.token_path_is_arn ? var.buildkite_agent_token_parameter_store_path : (
    local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"
  )

  # Computed agent token KMS key ARN (for IAM policies). A key in another account must be given as an ARN.
  agent_token_kms_key_arn = local.token_kms_key_is_arn ? var.buildkite_agent_token_parameter_store_kms_key : "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${var.buildkite_agent_token_parameter_store_kms_key}"

  # Determine AMI ID from custom, parameter, or Buildkite mapping
  computed_ami_id = local.use_custom_ami ? var.image_id : (local.use_ami_parameter ? data.aws_ssm_parameter.ami[0].value : local.selected_ami_id)

  # Windows and Ubuntu AMIs root on /dev/sda1; Amazon Linux roots on /dev/xvda.
  root_device_name = local.use_default_volume_name ? (local.is_windows || local.is_ubuntu ? "/dev/sda1" : "/dev/xvda") : var.root_volume_name

  # SSH key and authorized users settings
  use_ssh_key        = var.key_name != ""
  enable_ssh_ingress = local.create_security_group && (local.use_ssh_key || var.authorized_users_url != "")

  # Cost allocation tag settings
  enable_cost_tags = var.enable_cost_allocation_tags

  # Stack naming and tagging
  stack_name_full = "${var.stack_name}-${random_id.stack_suffix.hex}"

  # aws_iam_role.name_prefix must be <= 38 chars because the AWS provider appends
  # a generated suffix and IAM role names must be <= 64 chars.
  stop_buildkite_agents_role_name_prefix = substr("${local.stack_name_full}-stop-bk-", 0, 38)

  common_tags = merge(
    var.tags,
    local.enable_cost_tags ? {
      (var.cost_allocation_tag_name) = var.cost_allocation_tag_value
    } : {},
    {
      ManagedBy = "Terraform"
      Stack     = local.stack_name_full
    }
  )
}
