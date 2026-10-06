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
    us-east-1                    = { linuxamd64 = "ami-02195be60450ba632", linuxarm64 = "ami-02a030358b760546e", windows = "ami-0e7d6f121b8278376", ubuntu2404amd64 = "ami-0f99b98de0513fdb9", ubuntu2404arm64 = "ami-083452123609af70c" }
    us-east-2                    = { linuxamd64 = "ami-0c1c6fadc88ce63b4", linuxarm64 = "ami-0643f9b3b15108c24", windows = "ami-07aae05d3556167fd", ubuntu2404amd64 = "ami-0526609f5cabf540c", ubuntu2404arm64 = "ami-05a85f69a2451d0ad" }
    us-west-1                    = { linuxamd64 = "ami-0baec056a85e698d9", linuxarm64 = "ami-01c2ded24ce467381", windows = "ami-0d7acd1d86a59e6a3", ubuntu2404amd64 = "ami-06a1bea5a7a539686", ubuntu2404arm64 = "ami-00795c9ee22c02303" }
    us-west-2                    = { linuxamd64 = "ami-015c1d5d408404d24", linuxarm64 = "ami-089abfcdd33466cc6", windows = "ami-084cf5d60d2cded46", ubuntu2404amd64 = "ami-0afb1e095efd54c81", ubuntu2404arm64 = "ami-0d14c808e0233ff2d" }
    af-south-1                   = { linuxamd64 = "ami-0c980e44f7eb15d47", linuxarm64 = "ami-0ffd0e08db3fb0e82", windows = "ami-053637dac35788512", ubuntu2404amd64 = "ami-0fecf257d8fab6f75", ubuntu2404arm64 = "ami-0aa7dff95a02852d0" }
    ap-east-1                    = { linuxamd64 = "ami-03914d4719404a054", linuxarm64 = "ami-0f8be7240c16df196", windows = "ami-0e9eeb6c0ecd19235", ubuntu2404amd64 = "ami-0781f44f59d9f63b7", ubuntu2404arm64 = "ami-04778bd9d31bac415" }
    ap-south-1                   = { linuxamd64 = "ami-0b46a9c757d189cc9", linuxarm64 = "ami-0c8c8d884f4596bb7", windows = "ami-059ecca1835d14582", ubuntu2404amd64 = "ami-00855739778916278", ubuntu2404arm64 = "ami-0ee6457c0c276db87" }
    ap-northeast-2               = { linuxamd64 = "ami-0937a62e717fcb70d", linuxarm64 = "ami-09d80a709623ee01c", windows = "ami-00aa84f049b5d8110", ubuntu2404amd64 = "ami-09a42fd3df9bbb516", ubuntu2404arm64 = "ami-05bc79c921f4bbb1d" }
    ap-northeast-1               = { linuxamd64 = "ami-05de7b3974da42653", linuxarm64 = "ami-0de9a1865da65406a", windows = "ami-009967766d266afb3", ubuntu2404amd64 = "ami-050c3f64ac6100c24", ubuntu2404arm64 = "ami-0dee3aabba5fcab27" }
    ap-southeast-2               = { linuxamd64 = "ami-066eba4cb51e4e6d2", linuxarm64 = "ami-06cd5fd92806d8867", windows = "ami-07a8e64217200ec84", ubuntu2404amd64 = "ami-0e3ec4f88e8623513", ubuntu2404arm64 = "ami-075045f23142ce6dd" }
    ap-southeast-1               = { linuxamd64 = "ami-0886628ebb871051e", linuxarm64 = "ami-030c09b90faefac51", windows = "ami-042a6df94244d06f2", ubuntu2404amd64 = "ami-04fb6a53a2a633832", ubuntu2404arm64 = "ami-064e47768b5358d66" }
    ca-central-1                 = { linuxamd64 = "ami-094ca950e54e43cb9", linuxarm64 = "ami-078bda45808504555", windows = "ami-0becc22ec1f4aa0ed", ubuntu2404amd64 = "ami-0d5b670a1dcdfb311", ubuntu2404arm64 = "ami-07556d22864c68ab8" }
    eu-central-1                 = { linuxamd64 = "ami-0ea73b0ee297ae6c5", linuxarm64 = "ami-00078bb2cd6fad419", windows = "ami-084e2816749c25087", ubuntu2404amd64 = "ami-0c73998d9701797ca", ubuntu2404arm64 = "ami-028c1339eb3a8adb5" }
    eu-west-1                    = { linuxamd64 = "ami-0b98e2caa04a6fc6f", linuxarm64 = "ami-0aa47c07b702caee8", windows = "ami-0bb61f7be057a0a8e", ubuntu2404amd64 = "ami-05277a23c50866ed8", ubuntu2404arm64 = "ami-08cd09e7c74f28207" }
    eu-west-2                    = { linuxamd64 = "ami-0aed82e6c3a4e1998", linuxarm64 = "ami-05f90db3395099036", windows = "ami-058b49c35682ffb5f", ubuntu2404amd64 = "ami-0a6e02a26a9f1572a", ubuntu2404arm64 = "ami-0d525b7dce998f5d8" }
    eu-south-1                   = { linuxamd64 = "ami-0583f93405e84a4e2", linuxarm64 = "ami-0ca312cf33aa547d3", windows = "ami-01feb8b42ec069423", ubuntu2404amd64 = "ami-0cbdb19836a5bb9b2", ubuntu2404arm64 = "ami-08dc6903059776fd0" }
    eu-west-3                    = { linuxamd64 = "ami-07bdf9ff0b4bdb0f5", linuxarm64 = "ami-0ae57cd9efb980761", windows = "ami-0cea7744e05c55e94", ubuntu2404amd64 = "ami-04cc413dee33a5768", ubuntu2404arm64 = "ami-059e67fac40adc579" }
    eu-north-1                   = { linuxamd64 = "ami-01d879094221f896f", linuxarm64 = "ami-076ef310f84aedcc2", windows = "ami-007bf4272e20c5d4e", ubuntu2404amd64 = "ami-0cb39d46918211af4", ubuntu2404arm64 = "ami-0d04a403f6227e042" }
    sa-east-1                    = { linuxamd64 = "ami-042e3b8db3e36f85e", linuxarm64 = "ami-07d37acdec93ed637", windows = "ami-0da1b9cded52bea26", ubuntu2404amd64 = "ami-0c5888a9e214582b6", ubuntu2404arm64 = "ami-0b73c921616fb110d" }
    cloudformation_stack_version = "v6.71.5"
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
