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
    us-east-1                    = { linuxamd64 = "ami-03cbf3561e7c862b3", linuxarm64 = "ami-0285c81eec2fe09d9", windows = "ami-0403901d2a353bf36", ubuntu2404amd64 = "ami-05a0188d5956a6959", ubuntu2404arm64 = "ami-0a7d8fd8796cae03d" }
    us-east-2                    = { linuxamd64 = "ami-0ab7908299deab259", linuxarm64 = "ami-01ac3851b72b28ef1", windows = "ami-02de1b33bf76dfb6d", ubuntu2404amd64 = "ami-0222c434552a99d37", ubuntu2404arm64 = "ami-0a702e6d329d38847" }
    us-west-1                    = { linuxamd64 = "ami-05f68f1a3aba5e170", linuxarm64 = "ami-0bef0306a1d8d3d8b", windows = "ami-07b7eb26dde6b5f7e", ubuntu2404amd64 = "ami-057d996102335c743", ubuntu2404arm64 = "ami-012c043d10efa2a56" }
    us-west-2                    = { linuxamd64 = "ami-0583d31f97301842d", linuxarm64 = "ami-0513494695c918356", windows = "ami-01386a36f4c8a424f", ubuntu2404amd64 = "ami-0c7976ef5c3cd829d", ubuntu2404arm64 = "ami-0b38c67adbb412deb" }
    af-south-1                   = { linuxamd64 = "ami-02edcc4049d8bc76c", linuxarm64 = "ami-0f6e9222fd4957504", windows = "ami-02cc01cbda07ba246", ubuntu2404amd64 = "ami-08d7b4c67fad3514c", ubuntu2404arm64 = "ami-055e3f1b11ff9dcc6" }
    ap-east-1                    = { linuxamd64 = "ami-0e451c45b2931ab94", linuxarm64 = "ami-0b782ab326e8be40e", windows = "ami-0d5348ab0b6f23fe6", ubuntu2404amd64 = "ami-02ca03942bed9241a", ubuntu2404arm64 = "ami-0995dc92d02a3d795" }
    ap-south-1                   = { linuxamd64 = "ami-02c0c79442175416e", linuxarm64 = "ami-04fa4257ca50f7d7e", windows = "ami-0ad18ae03edbdb707", ubuntu2404amd64 = "ami-02390e3c85f78beea", ubuntu2404arm64 = "ami-099064e9a46e57720" }
    ap-northeast-2               = { linuxamd64 = "ami-0f55d7fab7349a7ce", linuxarm64 = "ami-09016e5aab2a53220", windows = "ami-027f32db0ac70c753", ubuntu2404amd64 = "ami-05dd5fc68a4745da7", ubuntu2404arm64 = "ami-03bbb5043911edefa" }
    ap-northeast-1               = { linuxamd64 = "ami-0aaeae4d6337a7e32", linuxarm64 = "ami-024c87bc23b46f5fd", windows = "ami-059f6bfb32b143950", ubuntu2404amd64 = "ami-08d592382254f8259", ubuntu2404arm64 = "ami-02f98f8fb0b7a1f25" }
    ap-southeast-2               = { linuxamd64 = "ami-0434b5aae6619970a", linuxarm64 = "ami-0bc9d44af494e7e17", windows = "ami-0e3030cbd9d7c4381", ubuntu2404amd64 = "ami-0f9eccbb7d3f76aa8", ubuntu2404arm64 = "ami-0202f77e08025dbb3" }
    ap-southeast-1               = { linuxamd64 = "ami-0a7fec9346cead319", linuxarm64 = "ami-0370bb331e494546a", windows = "ami-0981d6b9a06f4dd4e", ubuntu2404amd64 = "ami-02ce23f025967d9d9", ubuntu2404arm64 = "ami-06ea5de94de381005" }
    ca-central-1                 = { linuxamd64 = "ami-07934e359c5ea9b6b", linuxarm64 = "ami-082c8ee4f1211962c", windows = "ami-04d73d3a6c6f860c4", ubuntu2404amd64 = "ami-0ddbeb410dedf9191", ubuntu2404arm64 = "ami-0d80a348cad5037f6" }
    eu-central-1                 = { linuxamd64 = "ami-0ffd7a9bf7f505537", linuxarm64 = "ami-0ab67861a7c690283", windows = "ami-0fc265c49a202db64", ubuntu2404amd64 = "ami-03532385782159375", ubuntu2404arm64 = "ami-0b9c6711c43c89689" }
    eu-west-1                    = { linuxamd64 = "ami-08913e3b2149af2dd", linuxarm64 = "ami-0494026b759219372", windows = "ami-0700327292afa2427", ubuntu2404amd64 = "ami-05ec81668cbf19ab7", ubuntu2404arm64 = "ami-0f5bf4c7af53a3e0e" }
    eu-west-2                    = { linuxamd64 = "ami-076e842265b412b0e", linuxarm64 = "ami-0acfb6265bc046545", windows = "ami-0ead2edebb8623233", ubuntu2404amd64 = "ami-048f664f811b58d89", ubuntu2404arm64 = "ami-05ba90ba109d1acf5" }
    eu-south-1                   = { linuxamd64 = "ami-07860a6de6086a70a", linuxarm64 = "ami-0e8815c34217bbae6", windows = "ami-0931e904f90a008cc", ubuntu2404amd64 = "ami-063b5af82f70a7dae", ubuntu2404arm64 = "ami-072694922fcad721f" }
    eu-west-3                    = { linuxamd64 = "ami-09dc33c7ecd57f139", linuxarm64 = "ami-088c8d04b1802ecc1", windows = "ami-02b01fbd5be84f7bc", ubuntu2404amd64 = "ami-05fa120ca05f551d1", ubuntu2404arm64 = "ami-0795fa4b8941232fb" }
    eu-north-1                   = { linuxamd64 = "ami-0f4f3d1131ab7afbc", linuxarm64 = "ami-00bd7e3eac2cfc496", windows = "ami-068804e4d6ec6f050", ubuntu2404amd64 = "ami-018862a50941536e1", ubuntu2404arm64 = "ami-01447c3a9d8b21061" }
    sa-east-1                    = { linuxamd64 = "ami-07b05c0c8c7502fd8", linuxarm64 = "ami-041443b86f3285631", windows = "ami-0f2eeec22068db53d", ubuntu2404amd64 = "ami-00aa42cbd985a13ce", ubuntu2404arm64 = "ami-0d164d38b220ab2f6" }
    cloudformation_stack_version = "v7.11.1"
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
  ami_architecture = local.is_windows ? "windows" : (
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
