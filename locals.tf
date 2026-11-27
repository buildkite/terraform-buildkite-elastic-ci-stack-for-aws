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
    us-east-1                    = { linuxamd64 = "ami-0b43f750468cc2717", linuxarm64 = "ami-04ed8f2d0fe04d197", windows = "ami-0b7daff1db7dc9fee", ubuntu2404amd64 = "ami-0f19fcbf0e0ce68ab", ubuntu2404arm64 = "ami-03c76d9aeeeb41f0f", windows2025 = "ami-0c9ad7ed82204ccbd" }
    us-east-2                    = { linuxamd64 = "ami-08bfaadffe2fe6c52", linuxarm64 = "ami-098c7271f5fdf49d8", windows = "ami-0c0969f5e58b56ba0", ubuntu2404amd64 = "ami-00241b75c820ea6ac", ubuntu2404arm64 = "ami-000ed9e218dfbc153", windows2025 = "ami-0bab4ce44452e0c56" }
    us-west-1                    = { linuxamd64 = "ami-07dfbefcaec9c1ed0", linuxarm64 = "ami-0a04d12df4d9c2e70", windows = "ami-0fe518f62877e744a", ubuntu2404amd64 = "ami-09a21d31628c9dc84", ubuntu2404arm64 = "ami-05e2d4044e545be82", windows2025 = "ami-06ef06b2fe8f88650" }
    us-west-2                    = { linuxamd64 = "ami-0bb85fdee892a1eff", linuxarm64 = "ami-09cc9e126aeec3b69", windows = "ami-0604ced64558d3389", ubuntu2404amd64 = "ami-0822b61734e55b2f4", ubuntu2404arm64 = "ami-068f687b430a578f1", windows2025 = "ami-0634409a96f8e14f6" }
    af-south-1                   = { linuxamd64 = "ami-03945387afe19c6aa", linuxarm64 = "ami-0092f39f0a85df2d0", windows = "ami-0c2e8cf2350726849", ubuntu2404amd64 = "ami-0b8e5a8f41f2b743c", ubuntu2404arm64 = "ami-06c2933413aeee302", windows2025 = "ami-08a4657505b3e6515" }
    ap-east-1                    = { linuxamd64 = "ami-042427e81b6220e3e", linuxarm64 = "ami-00f10bb90c7fb675a", windows = "ami-086190a6b00d2615f", ubuntu2404amd64 = "ami-01825759e201be24c", ubuntu2404arm64 = "ami-0f5f16d9c38540501", windows2025 = "ami-0ca95421f4957b4aa" }
    ap-south-1                   = { linuxamd64 = "ami-0b8264c8af78eb9fd", linuxarm64 = "ami-020f7d4ac3a0f8ba8", windows = "ami-0a0b169b085e26a10", ubuntu2404amd64 = "ami-08a2a0b1a47a89726", ubuntu2404arm64 = "ami-0656272afafb9be36", windows2025 = "ami-0e05b67cec6d44178" }
    ap-northeast-2               = { linuxamd64 = "ami-0f6a1e650fe2c06ba", linuxarm64 = "ami-059c4d3cb32bf60ed", windows = "ami-0eded8aea6794f9f3", ubuntu2404amd64 = "ami-0d5d05a7fded2021f", ubuntu2404arm64 = "ami-02726ac232ed41408", windows2025 = "ami-034f306ffa4aef03b" }
    ap-northeast-1               = { linuxamd64 = "ami-046766ed5e5a06bea", linuxarm64 = "ami-009947f2eb8ab8123", windows = "ami-0f58380bee1c17969", ubuntu2404amd64 = "ami-065d5f3f5c9907a5e", ubuntu2404arm64 = "ami-09489b2336aeb5137", windows2025 = "ami-0656a4e738eb94990" }
    ap-southeast-2               = { linuxamd64 = "ami-0063800a94bc29343", linuxarm64 = "ami-06c805ef0e3088c0a", windows = "ami-0f477c7e225d438bd", ubuntu2404amd64 = "ami-005d5600d83edd077", ubuntu2404arm64 = "ami-007112c534cf877a3", windows2025 = "ami-02a9c23d7629a09c2" }
    ap-southeast-1               = { linuxamd64 = "ami-0690694906763305c", linuxarm64 = "ami-018f9c8f70fdbdf1c", windows = "ami-024c5f5185806f277", ubuntu2404amd64 = "ami-0814351f03ba99b7e", ubuntu2404arm64 = "ami-0a7bd3df6c6f46e91", windows2025 = "ami-0b4ef842e6d124f9a" }
    ca-central-1                 = { linuxamd64 = "ami-099aaf0e643c74da0", linuxarm64 = "ami-0c92b0e4a091186f1", windows = "ami-0fdf72f8e75f0c31d", ubuntu2404amd64 = "ami-0b666586244809ba2", ubuntu2404arm64 = "ami-0d48f493acea5723d", windows2025 = "ami-0abbb956ce2726ca3" }
    eu-central-1                 = { linuxamd64 = "ami-0abfff55d3510d8b0", linuxarm64 = "ami-0dab66cbf2b64596c", windows = "ami-026ddb77093f6dcbd", ubuntu2404amd64 = "ami-0e3094b8ff72971ea", ubuntu2404arm64 = "ami-096ecc0eebbcd7321", windows2025 = "ami-067d603f90dee8dc0" }
    eu-west-1                    = { linuxamd64 = "ami-0d5957e3c39c54871", linuxarm64 = "ami-0e3584145915c6077", windows = "ami-0b083d519628d9433", ubuntu2404amd64 = "ami-03e147298772e6dc9", ubuntu2404arm64 = "ami-077e7a35a570ad582", windows2025 = "ami-02db71c9af54f82f2" }
    eu-west-2                    = { linuxamd64 = "ami-04fb9698770be08ba", linuxarm64 = "ami-02681fbb0c6ffb20b", windows = "ami-0208ebb241d698999", ubuntu2404amd64 = "ami-069e842e51f62d09f", ubuntu2404arm64 = "ami-0d8ad84765118d3e3", windows2025 = "ami-0d6969efdd332ad2d" }
    eu-south-1                   = { linuxamd64 = "ami-0316eda3b2b5b7ec2", linuxarm64 = "ami-0d65b826dc498957c", windows = "ami-016977566e1c12956", ubuntu2404amd64 = "ami-08a24280dd6d7e107", ubuntu2404arm64 = "ami-0fc795a806299654d", windows2025 = "ami-034993a3d3ff276e0" }
    eu-west-3                    = { linuxamd64 = "ami-02c02adf499fd064a", linuxarm64 = "ami-0cd5aa9f97e179325", windows = "ami-0f1495cf506e6b26e", ubuntu2404amd64 = "ami-04561e14460b29790", ubuntu2404arm64 = "ami-0e2bfd9ab0940b9bc", windows2025 = "ami-036ace406283372ad" }
    eu-north-1                   = { linuxamd64 = "ami-03bd4685295564bad", linuxarm64 = "ami-02ebf79cae9d3c4f4", windows = "ami-064c00f3315756929", ubuntu2404amd64 = "ami-0f19b86da69f10f99", ubuntu2404arm64 = "ami-0f2454bf41feff0f1", windows2025 = "ami-0873636dda4d24d10" }
    sa-east-1                    = { linuxamd64 = "ami-07841fa6366acd92a", linuxarm64 = "ami-0e45047a908548a8e", windows = "ami-08f6c99aa375afb25", ubuntu2404amd64 = "ami-090b21e657897c493", ubuntu2404arm64 = "ami-0f391c35dc9383a65", windows2025 = "ami-0404f03434af60dae" }
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
