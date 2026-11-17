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
    us-east-1                    = { linuxamd64 = "ami-0f4233ba78a54a277", linuxarm64 = "ami-0db596df42f5b08c2", windows = "ami-076723d8b64ba22a6", ubuntu2404amd64 = "ami-0e369f83687a7ca7f", ubuntu2404arm64 = "ami-014d3defe40eddc14", windows2025 = "ami-086f2ccb76c71434f" }
    us-east-2                    = { linuxamd64 = "ami-02eb435d69e545072", linuxarm64 = "ami-0dd1265995745a3ee", windows = "ami-038054804561c28f1", ubuntu2404amd64 = "ami-02d1ae8762efdfe43", ubuntu2404arm64 = "ami-0d39d27a1df84c337", windows2025 = "ami-0f8e98a6a3f054ad4" }
    us-west-1                    = { linuxamd64 = "ami-0553e02393cabcb78", linuxarm64 = "ami-0e6527ee50bd6e630", windows = "ami-0c733643e349c708f", ubuntu2404amd64 = "ami-0bbd508933a778c79", ubuntu2404arm64 = "ami-0f4d4d507a71c5958", windows2025 = "ami-06a634592516a9068" }
    us-west-2                    = { linuxamd64 = "ami-0f9dd20731ddda37d", linuxarm64 = "ami-09db8a329c22cf47c", windows = "ami-066f02d44bbfdc380", ubuntu2404amd64 = "ami-0e0ecc2630f177c5f", ubuntu2404arm64 = "ami-00a11e7dfbe34a16e", windows2025 = "ami-0ecc99c12ed43ee86" }
    af-south-1                   = { linuxamd64 = "ami-04536ff1a9be85c90", linuxarm64 = "ami-03ed5d8f29c41dbc5", windows = "ami-0dcc0c6628b7f05c1", ubuntu2404amd64 = "ami-0ef98ae0b5a31fc31", ubuntu2404arm64 = "ami-0b5d9cf9ff5c47997", windows2025 = "ami-004ca1cb458236542" }
    ap-east-1                    = { linuxamd64 = "ami-0cc48eb0417f8b906", linuxarm64 = "ami-0a91d0b5c4930272c", windows = "ami-05b08fd81548d686b", ubuntu2404amd64 = "ami-06bd7bb85eda6a0dc", ubuntu2404arm64 = "ami-072a9f93dc1571b99", windows2025 = "ami-0f1fb6461be0cc4f7" }
    ap-south-1                   = { linuxamd64 = "ami-0a75f67ffaa26a623", linuxarm64 = "ami-03a895ce9cf412b42", windows = "ami-0791f8bd5a3cdcaf4", ubuntu2404amd64 = "ami-0ac6db20075ac5992", ubuntu2404arm64 = "ami-0b702960334f1cafe", windows2025 = "ami-0dc036b64c9c3386e" }
    ap-northeast-2               = { linuxamd64 = "ami-05b1cc25f8755c210", linuxarm64 = "ami-0f2e0dab2155452f4", windows = "ami-0364fef320f5d5061", ubuntu2404amd64 = "ami-0dc76dab4fc03d3a3", ubuntu2404arm64 = "ami-01287bf1d4364da08", windows2025 = "ami-0725e3919b7f2ed6b" }
    ap-northeast-1               = { linuxamd64 = "ami-0940e0d02fc96c9cb", linuxarm64 = "ami-02a07be1077189bf7", windows = "ami-0cf7b3b998c0b4cff", ubuntu2404amd64 = "ami-0412815de2430450d", ubuntu2404arm64 = "ami-0f11f0d9f53a88724", windows2025 = "ami-0dc27cc6703361626" }
    ap-southeast-2               = { linuxamd64 = "ami-05c12a4ff22b996ac", linuxarm64 = "ami-0ea86b1f5ee915515", windows = "ami-03c1649c556e38c12", ubuntu2404amd64 = "ami-0c47637ec845ea6f7", ubuntu2404arm64 = "ami-05e5082a4d29a5d79", windows2025 = "ami-0b2ff60f9caba8302" }
    ap-southeast-1               = { linuxamd64 = "ami-08f91e3f2c21d7a70", linuxarm64 = "ami-0d6b94f6ebedccc81", windows = "ami-0bee8bd1a02f7333a", ubuntu2404amd64 = "ami-059b52cb04b0f4ea3", ubuntu2404arm64 = "ami-0403bab16f6bddc58", windows2025 = "ami-0b5fb9a2bf4bc1107" }
    ca-central-1                 = { linuxamd64 = "ami-0382f231ebfffd2f1", linuxarm64 = "ami-0ccadd9b316b87a18", windows = "ami-0131fa7883d72adfa", ubuntu2404amd64 = "ami-072c6f065ec19199d", ubuntu2404arm64 = "ami-07d30bb23cee6bda7", windows2025 = "ami-09a70a9281fed8e33" }
    eu-central-1                 = { linuxamd64 = "ami-0d8b216c266a38fc6", linuxarm64 = "ami-09811bc7868bc900c", windows = "ami-00862fba7d6f6c053", ubuntu2404amd64 = "ami-0c95528cb0d03347a", ubuntu2404arm64 = "ami-0d0347ba16bb65df4", windows2025 = "ami-082f4a63422076164" }
    eu-west-1                    = { linuxamd64 = "ami-02bb283768d8ab952", linuxarm64 = "ami-0d74c08f60bf77d97", windows = "ami-03f05a3e2d6f7347c", ubuntu2404amd64 = "ami-0942c1dacbd95b1b2", ubuntu2404arm64 = "ami-096ec47397f30845d", windows2025 = "ami-0495ab019950ce0f7" }
    eu-west-2                    = { linuxamd64 = "ami-0e7c99917c1638782", linuxarm64 = "ami-026e3147299dd1cb1", windows = "ami-0a28fdfd61062cc74", ubuntu2404amd64 = "ami-0ca8cad9dfae4bb7d", ubuntu2404arm64 = "ami-086dda2430470a566", windows2025 = "ami-004fa582b8a047ca3" }
    eu-south-1                   = { linuxamd64 = "ami-0c896d874a5e6bbf2", linuxarm64 = "ami-0a7b16420c614d7e9", windows = "ami-026ef112619225b07", ubuntu2404amd64 = "ami-09817934c8d8956d1", ubuntu2404arm64 = "ami-0655fa03fcf80cb7a", windows2025 = "ami-0178cfad44f346da2" }
    eu-west-3                    = { linuxamd64 = "ami-086ae408a6e9b852d", linuxarm64 = "ami-0a28f504576b35003", windows = "ami-0aabd8367aef2e2c7", ubuntu2404amd64 = "ami-02d401109814377b6", ubuntu2404arm64 = "ami-07c6b236ca5937eec", windows2025 = "ami-098f698c7bbb86d73" }
    eu-north-1                   = { linuxamd64 = "ami-04038e99de591f369", linuxarm64 = "ami-0ab5ec279ab31373d", windows = "ami-0fee54a4b1ebe59e5", ubuntu2404amd64 = "ami-076233879bfd38062", ubuntu2404arm64 = "ami-0776dafbd2ff9d7df", windows2025 = "ami-009ea9a71e9f389c1" }
    sa-east-1                    = { linuxamd64 = "ami-0b7eec4d449fe0268", linuxarm64 = "ami-0923ffc0bffcc4c56", windows = "ami-02e0bd569282599a6", ubuntu2404amd64 = "ami-0038e7834732aa186", ubuntu2404arm64 = "ami-076a9b9def9545181", windows2025 = "ami-0f7f00edcbf5319e9" }
    cloudformation_stack_version = "v7.13.1"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.1"
  # Created and updated by the scaler itself, as in the upstream scaler template
  scaler_last_scale_in_parameter = "/buildkite-agent-scaler/${local.stack_name_full}/last-scale-in"
  # Attribute-based instance type selection replaces the instance_types list
  # with a single InstanceRequirements override on the Auto Scaling group.
  # https://docs.aws.amazon.com/autoscaling/ec2/userguide/create-mixed-instances-group-attribute-based-instance-type-selection.html
  use_instance_requirements = var.instance_requirements != null

  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM (AWS Graviton) families carry a "g" in the options position, right after
  # the generation digit (e.g. c8gd, m8gn, r8gb, x8g, i8g, hpc7g, g5g, x2gd). a1
  # is the original Graviton1 family and predates this convention, so it has no "g".
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  #
  # With instance requirements, Auto Scaling launches instance types that match
  # the architecture of the launch template's AMI, so the AMI comes from
  # instance_architecture (x86_64 by default) rather than from an instance type.
  # https://docs.aws.amazon.com/autoscaling/ec2/APIReference/API_InstanceRequirements.html
  is_arm_instance = var.instance_architecture != null ? var.instance_architecture == "arm64" : (
    local.use_instance_requirements ? false : (
      local.instance_type_family == "a1" ||
      can(regex("^[a-z]+[0-9]+g", local.instance_type_family))
    )
  )

  # Burstable (T series) instances earn and spend CPU credits. The "t" series
  # letter in the first position identifies them (t2, t3, t3a, t4g).
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  #
  # The AWS provider sends a launch template's CreditSpecification only when the
  # template's instance type is burstable. With instance requirements the
  # template has no instance type, so cpu_credits is not applied and T instances
  # use the account's default credit specification.
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-how-to.html
  is_burstable_instance = local.use_instance_requirements ? false : can(regex("^t[0-9]", local.instance_type_family))

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
