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
    us-east-1                    = { linuxamd64 = "ami-0583967f0b2f761b2", linuxarm64 = "ami-0bcbbe48e328fd1c8", windows = "ami-078187e273b110f04", ubuntu2404amd64 = "ami-059ae441fa366d70e", ubuntu2404arm64 = "ami-0e2baaaad71f27a84", windows2025 = "ami-0e41535990ee43fb6" }
    us-east-2                    = { linuxamd64 = "ami-0278401676792e4b2", linuxarm64 = "ami-08692794b6c3d7b24", windows = "ami-01ce40b209b139640", ubuntu2404amd64 = "ami-03e76268213e31b2d", ubuntu2404arm64 = "ami-0905d681a0de05686", windows2025 = "ami-0f0ae29fd615afea7" }
    us-west-1                    = { linuxamd64 = "ami-0086ebbd51c5dd4f7", linuxarm64 = "ami-0029a04c3b216c73a", windows = "ami-0799bc153f3c83cef", ubuntu2404amd64 = "ami-04997747ecbd7ea1f", ubuntu2404arm64 = "ami-0b2ee96df60bfd678", windows2025 = "ami-041db92cd10862478" }
    us-west-2                    = { linuxamd64 = "ami-01fd93e6cfbfa605a", linuxarm64 = "ami-0f4b8fb213712e5a9", windows = "ami-016fa69c742d9a984", ubuntu2404amd64 = "ami-0845535972ecbb5b0", ubuntu2404arm64 = "ami-0d080cd9f7beba673", windows2025 = "ami-0b350ed8198912d5b" }
    af-south-1                   = { linuxamd64 = "ami-0bdf3ff1a9504cb8a", linuxarm64 = "ami-0c8d6c4c7092b45f4", windows = "ami-0a9a25a13f509ced7", ubuntu2404amd64 = "ami-02f36d38556e4c32d", ubuntu2404arm64 = "ami-0b13f07c62d9d33b3", windows2025 = "ami-0dd24ebad602440bd" }
    ap-east-1                    = { linuxamd64 = "ami-07f4262b82a345c99", linuxarm64 = "ami-0e3c876fc62b0ef51", windows = "ami-0517f10753c59f540", ubuntu2404amd64 = "ami-02e35dc4fc6337c84", ubuntu2404arm64 = "ami-041dc20ca10cfc154", windows2025 = "ami-0b5d7cccbf1f1cb00" }
    ap-south-1                   = { linuxamd64 = "ami-010f8596209dc6426", linuxarm64 = "ami-0c52e58edbce0b63e", windows = "ami-0a1cf013824bec5da", ubuntu2404amd64 = "ami-05a079916eae2773f", ubuntu2404arm64 = "ami-0953cc5483ee05420", windows2025 = "ami-0fb5940050d450f9a" }
    ap-northeast-2               = { linuxamd64 = "ami-052c20501fa53b16d", linuxarm64 = "ami-0d8203e5a552fb8cb", windows = "ami-07d0b534159e9b7bc", ubuntu2404amd64 = "ami-0a6fd0a2547045a01", ubuntu2404arm64 = "ami-0804d15f32de00eaa", windows2025 = "ami-0ff7467400c0c17cc" }
    ap-northeast-1               = { linuxamd64 = "ami-098e5920c51b465f0", linuxarm64 = "ami-028b707d8466344e1", windows = "ami-02f4bf3fbfa9c47b0", ubuntu2404amd64 = "ami-0139999496ad52fe6", ubuntu2404arm64 = "ami-0a7f4efffe2d6c4cc", windows2025 = "ami-04e3b474947f31cb5" }
    ap-southeast-2               = { linuxamd64 = "ami-081d1dcb3ac534a90", linuxarm64 = "ami-073275c301e753ae0", windows = "ami-09ff5dfd3ef2cb9b9", ubuntu2404amd64 = "ami-097a8e45175bd6669", ubuntu2404arm64 = "ami-0ca42f0c00d084877", windows2025 = "ami-08f5bad3673d82075" }
    ap-southeast-1               = { linuxamd64 = "ami-07f66f9b60c553bed", linuxarm64 = "ami-02ef007572b8ff5c2", windows = "ami-07c86df7bb699194d", ubuntu2404amd64 = "ami-06d4a623b953d8143", ubuntu2404arm64 = "ami-006f5aeebfd90fd31", windows2025 = "ami-05f1bb245a5f54914" }
    ca-central-1                 = { linuxamd64 = "ami-0ebf1fe6a09df6ba8", linuxarm64 = "ami-0da2de2659a4fcc73", windows = "ami-0dd07aa896adc31dc", ubuntu2404amd64 = "ami-0c6b181ae3bddb271", ubuntu2404arm64 = "ami-0e510e1b646e47c4b", windows2025 = "ami-00e7de0bec395c546" }
    eu-central-1                 = { linuxamd64 = "ami-05e307a01b8c8b866", linuxarm64 = "ami-0937ef113cda1e76b", windows = "ami-0c43d26c193879c96", ubuntu2404amd64 = "ami-021ef99a0077bd391", ubuntu2404arm64 = "ami-05e46b52846339765", windows2025 = "ami-0807a48c2255e186f" }
    eu-west-1                    = { linuxamd64 = "ami-0f0f1018bc7aed0b2", linuxarm64 = "ami-07b23394be4cacdc4", windows = "ami-09a6681f3db7cd1a7", ubuntu2404amd64 = "ami-0c273c048a32fdcef", ubuntu2404arm64 = "ami-05d5c9611cdce1de8", windows2025 = "ami-0cea6a67768f4e489" }
    eu-west-2                    = { linuxamd64 = "ami-041ccacbe8748be0e", linuxarm64 = "ami-0606b7347d50b7e3f", windows = "ami-0230761a97516e6c0", ubuntu2404amd64 = "ami-06b01e7dbd022c877", ubuntu2404arm64 = "ami-012b9439971869286", windows2025 = "ami-0680c00afe99005d8" }
    eu-south-1                   = { linuxamd64 = "ami-0c08e088fa302639e", linuxarm64 = "ami-0faf93abc26932e48", windows = "ami-0e13577eaf0f6fc43", ubuntu2404amd64 = "ami-092ed36276b37cc61", ubuntu2404arm64 = "ami-0169531bfa11c099a", windows2025 = "ami-0c95c0f2537a1531e" }
    eu-west-3                    = { linuxamd64 = "ami-0fc2ab0778cd70d25", linuxarm64 = "ami-0a1225e30d821fc8b", windows = "ami-0df657d63a6754e27", ubuntu2404amd64 = "ami-06af78797921543f0", ubuntu2404arm64 = "ami-0b215c9c2d75f758e", windows2025 = "ami-01c27645ab4edc39c" }
    eu-north-1                   = { linuxamd64 = "ami-01ccb28e8d6fe75db", linuxarm64 = "ami-08490147afd30b683", windows = "ami-0019f7599a762fe4f", ubuntu2404amd64 = "ami-08f3c96925917ba71", ubuntu2404arm64 = "ami-07b7a558dcc70ec3c", windows2025 = "ami-0dd32a9261423a758" }
    sa-east-1                    = { linuxamd64 = "ami-0690fbc5a98ba76ce", linuxarm64 = "ami-0b122fed58404c43b", windows = "ami-0f4c4a685797759a8", ubuntu2404amd64 = "ami-064828df0d79472f2", ubuntu2404arm64 = "ami-0d2d5147d46767c4c", windows2025 = "ami-0a25dcbe7df779814" }
    cloudformation_stack_version = "v7.13.1"
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
