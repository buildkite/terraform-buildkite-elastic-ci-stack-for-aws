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
  create_vpc            = var.vpc_id == ""
  create_security_group = length(var.security_group_ids) == 0
  use_custom_azs        = var.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.enable_secrets_plugin && var.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.secrets_bucket_encryption
  use_existing_secrets  = var.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.artifacts_bucket != ""

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

  use_managed_policies = length(var.managed_policy_arns) > 0


  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0959e82bae82abcb2", linuxarm64 = "ami-0f068852706b533a6", windows = "ami-01860caaddaac5ba7", ubuntu2404amd64 = "ami-0fb5ee9893c651d92", ubuntu2404arm64 = "ami-0e75c5e891cc822e8" }
    us-east-2                    = { linuxamd64 = "ami-061b2c0e2b8af70c1", linuxarm64 = "ami-0a72eb7f3ca9a1843", windows = "ami-0baa8c582f96824a0", ubuntu2404amd64 = "ami-0d7c10e801257c5f3", ubuntu2404arm64 = "ami-098926238d7d7bf86" }
    us-west-1                    = { linuxamd64 = "ami-00499d1381662069f", linuxarm64 = "ami-01c95a8c622a27050", windows = "ami-073d4c7778cc7915f", ubuntu2404amd64 = "ami-05c25f3e3bcb3b070", ubuntu2404arm64 = "ami-08f0ddd987dfc56f1" }
    us-west-2                    = { linuxamd64 = "ami-0dfdc2404819d973d", linuxarm64 = "ami-0f8eda98fdbedd7b8", windows = "ami-0e7879d9a2e4ae0da", ubuntu2404amd64 = "ami-0979d1ecef38d4246", ubuntu2404arm64 = "ami-0c00b61580ecee78b" }
    af-south-1                   = { linuxamd64 = "ami-072a4ed647f2a01ee", linuxarm64 = "ami-075b0c5b10cf36410", windows = "ami-0f1b4a21dc483d973", ubuntu2404amd64 = "ami-0c86b036eb846f75a", ubuntu2404arm64 = "ami-0e813ee84d137c133" }
    ap-east-1                    = { linuxamd64 = "ami-0a9301293f2949715", linuxarm64 = "ami-036cee471616ddfa5", windows = "ami-052de1a46faf4acde", ubuntu2404amd64 = "ami-0126ab5085d076d1e", ubuntu2404arm64 = "ami-07c60c4962515f7dc" }
    ap-south-1                   = { linuxamd64 = "ami-00fc87bcc41707b80", linuxarm64 = "ami-02799572dd183e81a", windows = "ami-05266d2b1ee5973a5", ubuntu2404amd64 = "ami-00f93799f03adc2dd", ubuntu2404arm64 = "ami-0c21ed5f7c995718d" }
    ap-northeast-2               = { linuxamd64 = "ami-0c86a547a542697b6", linuxarm64 = "ami-070ac4b1538862b4e", windows = "ami-0b9d614cbe9a05f73", ubuntu2404amd64 = "ami-099ec11eae9c79840", ubuntu2404arm64 = "ami-0da6856f08d48365d" }
    ap-northeast-1               = { linuxamd64 = "ami-03e130ee3b117317a", linuxarm64 = "ami-029ad2ca21e1672ae", windows = "ami-099ad79d4b626ee59", ubuntu2404amd64 = "ami-064420b3851d987b8", ubuntu2404arm64 = "ami-0ae2c74b2a87eb188" }
    ap-southeast-2               = { linuxamd64 = "ami-0a10d3410e1766efe", linuxarm64 = "ami-0ee44743048dd32bf", windows = "ami-0e1c16cf9fc836507", ubuntu2404amd64 = "ami-005ddfdcc0e1bbfa5", ubuntu2404arm64 = "ami-0b6525dd7e2d90b78" }
    ap-southeast-1               = { linuxamd64 = "ami-00bc474740f91fc10", linuxarm64 = "ami-05ecf84e55b5e775e", windows = "ami-04dc3b047cd9ff95d", ubuntu2404amd64 = "ami-0a9a21f73f097232e", ubuntu2404arm64 = "ami-059911852222133cd" }
    ca-central-1                 = { linuxamd64 = "ami-0626142feddaad250", linuxarm64 = "ami-07ec7a48063ae4d4a", windows = "ami-051d40ca8462d6608", ubuntu2404amd64 = "ami-0da9f821c263acc1a", ubuntu2404arm64 = "ami-06b9a5f27c5939ee4" }
    eu-central-1                 = { linuxamd64 = "ami-0010bb0dbb65d5de5", linuxarm64 = "ami-04d20c870b5368331", windows = "ami-0571eb646e74064b8", ubuntu2404amd64 = "ami-021fcc2f17b1a9f9a", ubuntu2404arm64 = "ami-0de021ed727bc147e" }
    eu-west-1                    = { linuxamd64 = "ami-0ad3fd4747a2ed9c5", linuxarm64 = "ami-018043a64df7c76e5", windows = "ami-053679d7cd5665873", ubuntu2404amd64 = "ami-017133390f8fa65dc", ubuntu2404arm64 = "ami-0a926abc246476d37" }
    eu-west-2                    = { linuxamd64 = "ami-035c60b0794191be9", linuxarm64 = "ami-02a29e478ac7f4686", windows = "ami-0833eaebde5aa073c", ubuntu2404amd64 = "ami-0eedfe5ce4647d9dc", ubuntu2404arm64 = "ami-02a97cdf646b4babc" }
    eu-south-1                   = { linuxamd64 = "ami-094c4316667969b4a", linuxarm64 = "ami-0196f69e3dda217ab", windows = "ami-0c728bfa1f232aeb6", ubuntu2404amd64 = "ami-08152efe27221eff4", ubuntu2404arm64 = "ami-03d566adce4633c67" }
    eu-west-3                    = { linuxamd64 = "ami-0df6f90bf2e3a22fc", linuxarm64 = "ami-091a1fa62d6386e89", windows = "ami-0cd99f208bedca920", ubuntu2404amd64 = "ami-024ee233d617a18ec", ubuntu2404arm64 = "ami-045f88ef9c238abed" }
    eu-north-1                   = { linuxamd64 = "ami-0838bcabe17dd5f27", linuxarm64 = "ami-021f2d53372e3340d", windows = "ami-0ba14c19b87742528", ubuntu2404amd64 = "ami-02dd136a76fb4c8e1", ubuntu2404arm64 = "ami-0caa80999e74ea3b5" }
    sa-east-1                    = { linuxamd64 = "ami-07d1f461f9f563e2b", linuxarm64 = "ami-0a73da9e783aa81c8", windows = "ami-01f5d5030d0876972", ubuntu2404amd64 = "ami-0386d5b34e7d1669a", ubuntu2404arm64 = "ami-0ed36b760746147c7" }
    cloudformation_stack_version = "v7.3.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.15.0"
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
  use_custom_token_kms     = var.buildkite_agent_token_parameter_store_kms_key != ""
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
  agent_token_parameter_arn = local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"

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
