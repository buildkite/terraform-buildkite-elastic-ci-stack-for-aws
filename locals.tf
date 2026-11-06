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
    us-east-1                    = { linuxamd64 = "ami-0fd0bc5e2b7e38e76", linuxarm64 = "ami-073ef1a1bc4f705ca", windows = "ami-0391c25a70e968ae4", ubuntu2404amd64 = "ami-02b1f143a45afa009", ubuntu2404arm64 = "ami-0de35636a796e5545" }
    us-east-2                    = { linuxamd64 = "ami-0451a5f8e2318d0eb", linuxarm64 = "ami-00ea44a982650f68e", windows = "ami-010fae8aa66366e6c", ubuntu2404amd64 = "ami-0a0fd88aee2e8b287", ubuntu2404arm64 = "ami-0babe4714d284bfcd" }
    us-west-1                    = { linuxamd64 = "ami-04f8f4637bdc1a223", linuxarm64 = "ami-0e0cc51244b9a76d0", windows = "ami-05d1ee481917d3e4b", ubuntu2404amd64 = "ami-0aea9ed8c4c00cb58", ubuntu2404arm64 = "ami-00c982b5e1516d1ae" }
    us-west-2                    = { linuxamd64 = "ami-040cb87465cfadf78", linuxarm64 = "ami-0cc41b2e78145b506", windows = "ami-0da2ff3f25dbb423a", ubuntu2404amd64 = "ami-07087abb327a2ec55", ubuntu2404arm64 = "ami-0338cab9bf3c17e16" }
    af-south-1                   = { linuxamd64 = "ami-04e4b71e6ee57d194", linuxarm64 = "ami-036005571b2be7962", windows = "ami-014b55a0bba74db76", ubuntu2404amd64 = "ami-0f21c28cabe6a58eb", ubuntu2404arm64 = "ami-08b0d91025893f983" }
    ap-east-1                    = { linuxamd64 = "ami-0b59bd6ef73d526e5", linuxarm64 = "ami-0d29a1c6e4b74cd67", windows = "ami-012b6c47199729d3d", ubuntu2404amd64 = "ami-07fd93ad0cb8b9ef6", ubuntu2404arm64 = "ami-0da8e3a5de1ace13a" }
    ap-south-1                   = { linuxamd64 = "ami-00b2487564f94ba67", linuxarm64 = "ami-0a77f4f94854be61c", windows = "ami-0b3c7c8df8cab813e", ubuntu2404amd64 = "ami-0d37112484a6223b4", ubuntu2404arm64 = "ami-071a4ed9717e5f944" }
    ap-northeast-2               = { linuxamd64 = "ami-01f5c7031614d6e15", linuxarm64 = "ami-0c48533c8d1e05350", windows = "ami-0434908181af318c4", ubuntu2404amd64 = "ami-045b4633e55672bc4", ubuntu2404arm64 = "ami-0e5d029329293d231" }
    ap-northeast-1               = { linuxamd64 = "ami-07e70cac040bb26e8", linuxarm64 = "ami-09a1655441c0c2a50", windows = "ami-08cc090ed96cfaa88", ubuntu2404amd64 = "ami-0b73bec468c4e13b4", ubuntu2404arm64 = "ami-0f0461ef6b8776f80" }
    ap-southeast-2               = { linuxamd64 = "ami-0c70617a2f89c4ad4", linuxarm64 = "ami-0c2104b4834b066f5", windows = "ami-05ac41813e25ebb7b", ubuntu2404amd64 = "ami-01e3115258f98f631", ubuntu2404arm64 = "ami-03f680936dd3c59d8" }
    ap-southeast-1               = { linuxamd64 = "ami-0e89cdf8958125d57", linuxarm64 = "ami-036d20addc464aeb5", windows = "ami-0dac5262aeef400d2", ubuntu2404amd64 = "ami-060f38079badab16d", ubuntu2404arm64 = "ami-0a96619fa6d330a35" }
    ca-central-1                 = { linuxamd64 = "ami-04c6abf08610033c7", linuxarm64 = "ami-06e38921a940d2ddf", windows = "ami-0f558a6c432b6ecc0", ubuntu2404amd64 = "ami-05363367ede7c0ecf", ubuntu2404arm64 = "ami-06b31e2678e45b361" }
    eu-central-1                 = { linuxamd64 = "ami-0c8f365ac92fd0845", linuxarm64 = "ami-092dd7d537fbeb973", windows = "ami-090df5d5084a6d975", ubuntu2404amd64 = "ami-0633ebf607f229a9b", ubuntu2404arm64 = "ami-0ac863788f2551a73" }
    eu-west-1                    = { linuxamd64 = "ami-0b6d15b6f49ecbf5b", linuxarm64 = "ami-0a2cef2c3a331984b", windows = "ami-06c7d7cb264f6284b", ubuntu2404amd64 = "ami-0e7cc89a2922830e6", ubuntu2404arm64 = "ami-060886e470e22cc9c" }
    eu-west-2                    = { linuxamd64 = "ami-008420da1a4420662", linuxarm64 = "ami-0a76ee2f3b11e09e1", windows = "ami-04d40baa1bf20c6e3", ubuntu2404amd64 = "ami-0688736855ef25abe", ubuntu2404arm64 = "ami-0e33f69b30d38efff" }
    eu-south-1                   = { linuxamd64 = "ami-0b86fd1d4713b1613", linuxarm64 = "ami-075f50843ae1a1ad4", windows = "ami-0bdbddd3317b1e00f", ubuntu2404amd64 = "ami-01ab18202515f23eb", ubuntu2404arm64 = "ami-0cb01c8ce408e898f" }
    eu-west-3                    = { linuxamd64 = "ami-00c931e5e9855ccb1", linuxarm64 = "ami-0f9d40b1c6d80b596", windows = "ami-0391ef482d2e95c0d", ubuntu2404amd64 = "ami-0bb9b973a3dc975ef", ubuntu2404arm64 = "ami-046ed530c8377cf2f" }
    eu-north-1                   = { linuxamd64 = "ami-039450a0083aaf6c6", linuxarm64 = "ami-060a296f3a4fc2a3b", windows = "ami-03278de49eee15388", ubuntu2404amd64 = "ami-071fc4b2f8e0a7908", ubuntu2404arm64 = "ami-050f4bf4caf22b39e" }
    sa-east-1                    = { linuxamd64 = "ami-02a1e50c90406faf9", linuxarm64 = "ami-055275c46d5db3f4d", windows = "ami-0ffbfefe0833e6a5a", ubuntu2404amd64 = "ami-0fef1b46edfc26810", ubuntu2404arm64 = "ami-0a0bb78edf843576f" }
    cloudformation_stack_version = "v7.11.0"
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
