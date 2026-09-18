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
    us-east-1                    = { linuxamd64 = "ami-09904f7841e0bc4f5", linuxarm64 = "ami-0a21da0842f6230d1", windows = "ami-0c86c66600b76ed91", ubuntu2404amd64 = "ami-0706409f016596802", ubuntu2404arm64 = "ami-07507da6b2609fd12" }
    us-east-2                    = { linuxamd64 = "ami-0c9f81539c3058bbd", linuxarm64 = "ami-03cf6ceb5a853eace", windows = "ami-044711db01186d4c2", ubuntu2404amd64 = "ami-005191f0d2a4bd1c6", ubuntu2404arm64 = "ami-0fbd00440cfbf8657" }
    us-west-1                    = { linuxamd64 = "ami-0c6083b367dfd1df9", linuxarm64 = "ami-0f8fa5a9d3d7f438a", windows = "ami-00eb2130eab760980", ubuntu2404amd64 = "ami-09e54998d375e9b84", ubuntu2404arm64 = "ami-0efb52d5e25996357" }
    us-west-2                    = { linuxamd64 = "ami-0e8dc0c35086ad51f", linuxarm64 = "ami-0f43baacbe960e3dc", windows = "ami-01f8b3bb79f665837", ubuntu2404amd64 = "ami-0c5800c371b0ba833", ubuntu2404arm64 = "ami-087a9512f82c9a5ea" }
    af-south-1                   = { linuxamd64 = "ami-0fbbe1c2c4bf9bd6f", linuxarm64 = "ami-0f4bd3bf9cc242343", windows = "ami-08c7d591ea43e7457", ubuntu2404amd64 = "ami-0f4b7fc275c305ba9", ubuntu2404arm64 = "ami-0a47b8cdc747e9b6d" }
    ap-east-1                    = { linuxamd64 = "ami-042d2eb1f63033759", linuxarm64 = "ami-0f32ef9bd7b12a682", windows = "ami-04ca75aa7e27e7113", ubuntu2404amd64 = "ami-0f163a9fa0d6ff822", ubuntu2404arm64 = "ami-03d832ee9a63e78c9" }
    ap-south-1                   = { linuxamd64 = "ami-0e196b725ca05b2fa", linuxarm64 = "ami-0f614982581d26586", windows = "ami-0911e98838fa8d266", ubuntu2404amd64 = "ami-0d2832658a81b7fde", ubuntu2404arm64 = "ami-07cd6657d34aa95bb" }
    ap-northeast-2               = { linuxamd64 = "ami-041cfa1e25a93cfef", linuxarm64 = "ami-09448f1ac86596f40", windows = "ami-0a165e61453817970", ubuntu2404amd64 = "ami-01754ef97b4723b72", ubuntu2404arm64 = "ami-0f81bbc8266a15fbc" }
    ap-northeast-1               = { linuxamd64 = "ami-0de7ef040c683adfa", linuxarm64 = "ami-0f4a176e0e7b9dafe", windows = "ami-029b0c4e1df75546c", ubuntu2404amd64 = "ami-0714117b8715c8551", ubuntu2404arm64 = "ami-0a3d51e91f250e56c" }
    ap-southeast-2               = { linuxamd64 = "ami-0e4831bee8b773f3f", linuxarm64 = "ami-0829d4625637b1ed2", windows = "ami-02891f6932a79c6c5", ubuntu2404amd64 = "ami-03387f07bb3e909c9", ubuntu2404arm64 = "ami-0152e5185202f27a7" }
    ap-southeast-1               = { linuxamd64 = "ami-0cbf00766ffdcaff3", linuxarm64 = "ami-0221880af4968d0a5", windows = "ami-02775e26fd80eabeb", ubuntu2404amd64 = "ami-0ffc269ae898c628d", ubuntu2404arm64 = "ami-05d7ba6b906835866" }
    ca-central-1                 = { linuxamd64 = "ami-0eb0f49fd92f56309", linuxarm64 = "ami-0b46868dc2212b225", windows = "ami-009c7a380118799b1", ubuntu2404amd64 = "ami-0774bbd07ca314f88", ubuntu2404arm64 = "ami-0bd7c52d9e5fd6797" }
    eu-central-1                 = { linuxamd64 = "ami-06ec3a99597637d0f", linuxarm64 = "ami-01b33aae47725e467", windows = "ami-05462f17d7646ea4a", ubuntu2404amd64 = "ami-06476eed80fa2ffd5", ubuntu2404arm64 = "ami-04ddd7794513dd5b4" }
    eu-west-1                    = { linuxamd64 = "ami-045692a6a9dfb73a1", linuxarm64 = "ami-0942ae0be0018f771", windows = "ami-0c509366da433fe8e", ubuntu2404amd64 = "ami-0bf08279993a58e01", ubuntu2404arm64 = "ami-041a60b212147c0ef" }
    eu-west-2                    = { linuxamd64 = "ami-0925acc54cf31cef3", linuxarm64 = "ami-0eca10ff06b90e4b2", windows = "ami-01508d4c7fca255a6", ubuntu2404amd64 = "ami-036670f94e2f0d5f5", ubuntu2404arm64 = "ami-08d8f729fca19484a" }
    eu-south-1                   = { linuxamd64 = "ami-01608651fdf071839", linuxarm64 = "ami-010dfd1fd5576e61e", windows = "ami-0706dbe0ff0c752e1", ubuntu2404amd64 = "ami-00446f7bc6be8d38f", ubuntu2404arm64 = "ami-0a51816cb99ebe658" }
    eu-west-3                    = { linuxamd64 = "ami-00f3f2cae55041271", linuxarm64 = "ami-0df3d7398fd9b6570", windows = "ami-08300d2e7a18f2bdf", ubuntu2404amd64 = "ami-0ec7658a2f7b74fd1", ubuntu2404arm64 = "ami-0cd6dd81da51cbdd4" }
    eu-north-1                   = { linuxamd64 = "ami-03f5e022aa7e5a46a", linuxarm64 = "ami-0a72ca5796a24c326", windows = "ami-06c27dd19f93ac94a", ubuntu2404amd64 = "ami-0b3d524288cf1acf2", ubuntu2404arm64 = "ami-0b3fb7995faf5c12b" }
    sa-east-1                    = { linuxamd64 = "ami-0c24e2b3665f34742", linuxarm64 = "ami-05bfd24809a7ff25b", windows = "ami-0aa897eae9d28ff47", ubuntu2404amd64 = "ami-0815effe5fe3e9b6c", ubuntu2404arm64 = "ami-05227f3b5787c4be5" }
    cloudformation_stack_version = "v7.0.0"
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
