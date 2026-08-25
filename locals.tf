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
    us-east-1                    = { linuxamd64 = "ami-07701120871bb45b7", linuxarm64 = "ami-0b55f314b7dbb4157", windows = "ami-0609cf3fbdcbadffe", ubuntu2404amd64 = "ami-0e389c224f18b0753", ubuntu2404arm64 = "ami-03ba77b3b9d459993" }
    us-east-2                    = { linuxamd64 = "ami-0ff48c0ada31c199b", linuxarm64 = "ami-04b6323d2353ddae7", windows = "ami-0cdfeb53b73593a4f", ubuntu2404amd64 = "ami-07c9c5dfb8aad2a37", ubuntu2404arm64 = "ami-069923d5dde14186f" }
    us-west-1                    = { linuxamd64 = "ami-0ac4991f7af1c943e", linuxarm64 = "ami-038db75e2913b2302", windows = "ami-09d01982bf23c48ea", ubuntu2404amd64 = "ami-031cde53d35f964f0", ubuntu2404arm64 = "ami-055e5422f75b26e07" }
    us-west-2                    = { linuxamd64 = "ami-09ba24e3674137747", linuxarm64 = "ami-0f626a430bf06d3e7", windows = "ami-071082b864a96187e", ubuntu2404amd64 = "ami-0abe7e747a0ddee03", ubuntu2404arm64 = "ami-009265140fe160063" }
    af-south-1                   = { linuxamd64 = "ami-06a47a882efee1432", linuxarm64 = "ami-07afefd379fb8d49f", windows = "ami-0436a15a8ffb0ec17", ubuntu2404amd64 = "ami-0f1161cc5d4394c5f", ubuntu2404arm64 = "ami-0635e8174321580c2" }
    ap-east-1                    = { linuxamd64 = "ami-0f882d251bfbb9d5a", linuxarm64 = "ami-08215ce9a358274af", windows = "ami-0e2b0bdb2678750b6", ubuntu2404amd64 = "ami-0c61328a49582f112", ubuntu2404arm64 = "ami-0417ed73d043ad904" }
    ap-south-1                   = { linuxamd64 = "ami-08d5d558f113cfd71", linuxarm64 = "ami-0e5d059b949006f12", windows = "ami-01b0585344b9229d2", ubuntu2404amd64 = "ami-0e3d240c7343c9d76", ubuntu2404arm64 = "ami-0edb0b7019398e0a8" }
    ap-northeast-2               = { linuxamd64 = "ami-04e953639b306f5c4", linuxarm64 = "ami-0ff40c602c14d9d43", windows = "ami-0ede0c251e0328437", ubuntu2404amd64 = "ami-051ecd2a105ee7a7f", ubuntu2404arm64 = "ami-0dae1640677e7c31e" }
    ap-northeast-1               = { linuxamd64 = "ami-07e95412764d93dc0", linuxarm64 = "ami-059b6b53b741644ca", windows = "ami-0020c9b338f9fb4c7", ubuntu2404amd64 = "ami-074952c9d101655bf", ubuntu2404arm64 = "ami-0b52f37111dd01709" }
    ap-southeast-2               = { linuxamd64 = "ami-021c0d2a3838e5508", linuxarm64 = "ami-083b0ef8f916528d4", windows = "ami-05d1f76ce0518e0bc", ubuntu2404amd64 = "ami-0587dd553e6002620", ubuntu2404arm64 = "ami-042a79683ae4c6768" }
    ap-southeast-1               = { linuxamd64 = "ami-038611e6155ec3500", linuxarm64 = "ami-0f5ca3296ef0c0e99", windows = "ami-0375f49f5adf23ea9", ubuntu2404amd64 = "ami-09826206b6f7b055f", ubuntu2404arm64 = "ami-08af1a99db398e270" }
    ca-central-1                 = { linuxamd64 = "ami-09904f16c2054b0ca", linuxarm64 = "ami-02ffc328bc41c9035", windows = "ami-0f0524984e0cbebf3", ubuntu2404amd64 = "ami-085fbec0a9b5c8573", ubuntu2404arm64 = "ami-06fd9c61afd6ed7f5" }
    eu-central-1                 = { linuxamd64 = "ami-020d91d6040e3d97d", linuxarm64 = "ami-01ca82f0ca93d4a89", windows = "ami-0c969526ae8821617", ubuntu2404amd64 = "ami-096457c78cf946a6e", ubuntu2404arm64 = "ami-091dd7da5f952f88f" }
    eu-west-1                    = { linuxamd64 = "ami-092fea5011d324a6d", linuxarm64 = "ami-0fbaffc92d3c0bab7", windows = "ami-0513e814927a19ffd", ubuntu2404amd64 = "ami-04bc34ca5753fe2a9", ubuntu2404arm64 = "ami-0351bf8c77fbe24e6" }
    eu-west-2                    = { linuxamd64 = "ami-05649fdf88dce23db", linuxarm64 = "ami-08966b4dc3013cbd4", windows = "ami-0749b1b89af699d20", ubuntu2404amd64 = "ami-0dc1e5e8786fe83ab", ubuntu2404arm64 = "ami-05513eb7f648c14a2" }
    eu-south-1                   = { linuxamd64 = "ami-0564f5c05e40627ed", linuxarm64 = "ami-043c32988b1e2deeb", windows = "ami-0422f329ae43849d3", ubuntu2404amd64 = "ami-0b8ffbf961493c08a", ubuntu2404arm64 = "ami-076ad18211ab6b218" }
    eu-west-3                    = { linuxamd64 = "ami-0ed15023ea402387b", linuxarm64 = "ami-07a4b8e644b0ef03f", windows = "ami-084e21ee48e6e29d1", ubuntu2404amd64 = "ami-0db6caaa0ca129379", ubuntu2404arm64 = "ami-0191800bbcfb454db" }
    eu-north-1                   = { linuxamd64 = "ami-0a1f25ac9bb35a37d", linuxarm64 = "ami-05c5489a86a5eb7da", windows = "ami-092e9006b236e570e", ubuntu2404amd64 = "ami-0dcbf549a16918cc2", ubuntu2404arm64 = "ami-0cc700179e4989be6" }
    sa-east-1                    = { linuxamd64 = "ami-02334735057902034", linuxarm64 = "ami-0fa528e720dc8c35f", windows = "ami-0cc40d82190164089", ubuntu2404amd64 = "ami-0781b4907e8b86f50", ubuntu2404arm64 = "ami-00676295d3540bb0a" }
    cloudformation_stack_version = "v6.71.1"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.13.0"
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
