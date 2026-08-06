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
    us-east-1                    = { linuxamd64 = "ami-004e1c63d989d8032", linuxarm64 = "ami-04eb474e8a7798945", windows = "ami-0aeeb6cad86a8b647", ubuntu2404amd64 = "ami-06088cbba76a28c4a", ubuntu2404arm64 = "ami-0930b7998a0b3012d" }
    us-east-2                    = { linuxamd64 = "ami-016029a5c910dab1d", linuxarm64 = "ami-0e508c0590ab6773f", windows = "ami-0acef228bafcc4955", ubuntu2404amd64 = "ami-04b36920fe03a8eac", ubuntu2404arm64 = "ami-08ddabd7f22519e30" }
    us-west-1                    = { linuxamd64 = "ami-03f03b0bc932a3cb7", linuxarm64 = "ami-04b679ba36737aaa5", windows = "ami-0325a4b25a917e002", ubuntu2404amd64 = "ami-0a4d7b5695dcb8f28", ubuntu2404arm64 = "ami-042d142137525fc54" }
    us-west-2                    = { linuxamd64 = "ami-0fe78447568b71e68", linuxarm64 = "ami-0c96b5c041fce39a9", windows = "ami-0501796d816956821", ubuntu2404amd64 = "ami-0fb7dadcf7d28299f", ubuntu2404arm64 = "ami-01a15ed877208655a" }
    af-south-1                   = { linuxamd64 = "ami-0ca3c57e1cba4910f", linuxarm64 = "ami-0110e5f0b8193e3c4", windows = "ami-00cc8119df1bb8014", ubuntu2404amd64 = "ami-05d24ff08f5144405", ubuntu2404arm64 = "ami-03230cdde4d4b5b9f" }
    ap-east-1                    = { linuxamd64 = "ami-0a568a88e27e12ac4", linuxarm64 = "ami-045bfc4a2a014dad7", windows = "ami-0515acf2a94b5a706", ubuntu2404amd64 = "ami-0b42e710f82957678", ubuntu2404arm64 = "ami-00b28153441d79449" }
    ap-south-1                   = { linuxamd64 = "ami-0d9f0e2503bff71e0", linuxarm64 = "ami-0fead4689524a540b", windows = "ami-0bd83cc4da7e4d9eb", ubuntu2404amd64 = "ami-0fe251a10e6d4ca5f", ubuntu2404arm64 = "ami-06bd0887039bb73bb" }
    ap-northeast-2               = { linuxamd64 = "ami-0090ca9591c290e02", linuxarm64 = "ami-01fb8dbb37fd0eb5c", windows = "ami-0d36bd4c7498efb1b", ubuntu2404amd64 = "ami-00d1bfe17f3e380d9", ubuntu2404arm64 = "ami-0c003f1c836938dc4" }
    ap-northeast-1               = { linuxamd64 = "ami-040735f175abe61e5", linuxarm64 = "ami-08147be7d5d6880ba", windows = "ami-0ef625c527e9b81f1", ubuntu2404amd64 = "ami-01f8583de776a83cc", ubuntu2404arm64 = "ami-074d5b4cf0a726fba" }
    ap-southeast-2               = { linuxamd64 = "ami-0118d3364882a1e8a", linuxarm64 = "ami-08d0a7f990d9a5819", windows = "ami-056f3c280f112755b", ubuntu2404amd64 = "ami-0846e9dc236b0a13a", ubuntu2404arm64 = "ami-02cc6ab50b2c9ffb8" }
    ap-southeast-1               = { linuxamd64 = "ami-077cc90143592c045", linuxarm64 = "ami-0e444562ef7786ed4", windows = "ami-02088a64950758cab", ubuntu2404amd64 = "ami-06490de9aa511f4e1", ubuntu2404arm64 = "ami-093ae524b0dd08322" }
    ca-central-1                 = { linuxamd64 = "ami-01ee357fef649e4f8", linuxarm64 = "ami-08551fe702a11f670", windows = "ami-08b0ad2a5b0e02c0a", ubuntu2404amd64 = "ami-0c03e3f7a564fda94", ubuntu2404arm64 = "ami-005e125bc2dcb1c62" }
    eu-central-1                 = { linuxamd64 = "ami-0407d0c9305af2963", linuxarm64 = "ami-0efdee046f61c5be6", windows = "ami-029a8d483d76b42df", ubuntu2404amd64 = "ami-0cdf9c96a9b5e651a", ubuntu2404arm64 = "ami-056c0d6a629cb9a0f" }
    eu-west-1                    = { linuxamd64 = "ami-0dc61d2ad8cb6c0ed", linuxarm64 = "ami-0d77ea44c37b500bc", windows = "ami-03d586ba2dfc1ff0a", ubuntu2404amd64 = "ami-08f29383d879bbc9c", ubuntu2404arm64 = "ami-0ac69cffb2f86ef96" }
    eu-west-2                    = { linuxamd64 = "ami-0ed0b38831b80caf4", linuxarm64 = "ami-0062eb3e8e2d32694", windows = "ami-0aef7e7043a59e4f5", ubuntu2404amd64 = "ami-029ae8826b034de58", ubuntu2404arm64 = "ami-0d96ae7051bfa0c12" }
    eu-south-1                   = { linuxamd64 = "ami-00f2b76648bf1a965", linuxarm64 = "ami-0937f7c02aaf5382d", windows = "ami-07dbd9b28e1759a09", ubuntu2404amd64 = "ami-08c5d5309ab755f05", ubuntu2404arm64 = "ami-02eb9c67e737dfd32" }
    eu-west-3                    = { linuxamd64 = "ami-01c8093bb87d4dc9c", linuxarm64 = "ami-0fab7e2891b22abfe", windows = "ami-039569aaa33edc228", ubuntu2404amd64 = "ami-05bd6a8c2e066e937", ubuntu2404arm64 = "ami-01f1f0c3ebf805271" }
    eu-north-1                   = { linuxamd64 = "ami-096ef619c906675d5", linuxarm64 = "ami-0a4d5afea0a802148", windows = "ami-01179f720014f69d8", ubuntu2404amd64 = "ami-0446eea38947d5bdc", ubuntu2404arm64 = "ami-084525465386e45a7" }
    sa-east-1                    = { linuxamd64 = "ami-0eb61bafec00778c6", linuxarm64 = "ami-051e6d9332207c1f6", windows = "ami-0f318be5408b731db", ubuntu2404amd64 = "ami-0c9efb0e9e1e74526", ubuntu2404arm64 = "ami-0a1c74a1b8de3f918" }
    cloudformation_stack_version = "v6.71.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.12.0"
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
