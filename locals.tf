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
    us-east-1                    = { linuxamd64 = "ami-0a49b6e009bcad179", linuxarm64 = "ami-06121b1719e226cb7", windows = "ami-0ac236c4f1964d60a", ubuntu2404amd64 = "ami-061b46ef0d9c38808", ubuntu2404arm64 = "ami-0134da9d8fc9e544f" }
    us-east-2                    = { linuxamd64 = "ami-0cd44289c9a0e9645", linuxarm64 = "ami-0ce16614fbb412171", windows = "ami-0273a991e373e137b", ubuntu2404amd64 = "ami-06eb217c4ca271964", ubuntu2404arm64 = "ami-015045633d117104f" }
    us-west-1                    = { linuxamd64 = "ami-00cf017a92392eeb7", linuxarm64 = "ami-0646d92dc4ac1c96d", windows = "ami-049e25fb2fc029ce7", ubuntu2404amd64 = "ami-008e8ec01e7ed289a", ubuntu2404arm64 = "ami-044a55ca862a49de7" }
    us-west-2                    = { linuxamd64 = "ami-04ad2bf62a171e0c3", linuxarm64 = "ami-0af0b3bdfb4109954", windows = "ami-005184ec0dd30274e", ubuntu2404amd64 = "ami-0d89f6fb92b7d9566", ubuntu2404arm64 = "ami-03c9c5a81099e8fb7" }
    af-south-1                   = { linuxamd64 = "ami-0b2195ca77ded62ed", linuxarm64 = "ami-022e77893bf98e424", windows = "ami-02e4538296bd10187", ubuntu2404amd64 = "ami-0ca0934ddf7fe3baa", ubuntu2404arm64 = "ami-0e2396a14c368ea50" }
    ap-east-1                    = { linuxamd64 = "ami-04319a4ccc7fb04b9", linuxarm64 = "ami-007d1fdf70d7a4d5d", windows = "ami-0ea46cf14aef31858", ubuntu2404amd64 = "ami-00897b4099000f665", ubuntu2404arm64 = "ami-0676f6daa190b1b0c" }
    ap-south-1                   = { linuxamd64 = "ami-065a35a330b4a765d", linuxarm64 = "ami-019d67e510c1b2a2e", windows = "ami-07e31697cb0d0a8f7", ubuntu2404amd64 = "ami-080960b3cb13221a1", ubuntu2404arm64 = "ami-0bf09984ef6c7508c" }
    ap-northeast-2               = { linuxamd64 = "ami-0f5012ac6a36dc132", linuxarm64 = "ami-0c10bb8af2671088e", windows = "ami-041d9bd6deea4528e", ubuntu2404amd64 = "ami-08015a4a012a4a960", ubuntu2404arm64 = "ami-08223c78db0af9d33" }
    ap-northeast-1               = { linuxamd64 = "ami-03b620c24c800f23a", linuxarm64 = "ami-0f5d5dde97ce01052", windows = "ami-0945566d725918d66", ubuntu2404amd64 = "ami-0e9fe92fe1fa45a92", ubuntu2404arm64 = "ami-088d4ee45cc9da051" }
    ap-southeast-2               = { linuxamd64 = "ami-051ca6db7de82c865", linuxarm64 = "ami-06abad2cdc3452ff0", windows = "ami-001721d1b3ad3de8a", ubuntu2404amd64 = "ami-0bd1ac3826677a495", ubuntu2404arm64 = "ami-0468f0023e7a0a3ea" }
    ap-southeast-1               = { linuxamd64 = "ami-0269e5cbad18b56d8", linuxarm64 = "ami-0085c50a84ec6e488", windows = "ami-0fcbee5d07eb9754e", ubuntu2404amd64 = "ami-0b54132e3c7aed5cd", ubuntu2404arm64 = "ami-067a312f773e27e79" }
    ca-central-1                 = { linuxamd64 = "ami-0d918b14ea1375c24", linuxarm64 = "ami-01e4041695cf8da7a", windows = "ami-037509fe462096650", ubuntu2404amd64 = "ami-0f7b14ab571dbadb7", ubuntu2404arm64 = "ami-07df12604bda80e62" }
    eu-central-1                 = { linuxamd64 = "ami-0881b80cc737852b5", linuxarm64 = "ami-02a3117ced6cbee98", windows = "ami-000a8301260384b78", ubuntu2404amd64 = "ami-05893670469c36bee", ubuntu2404arm64 = "ami-0929a9fa659f0ea1e" }
    eu-west-1                    = { linuxamd64 = "ami-07a896cbad12cd565", linuxarm64 = "ami-0d45345d8c829cfff", windows = "ami-0be05ed8803af6981", ubuntu2404amd64 = "ami-00744e4cee93e8b7f", ubuntu2404arm64 = "ami-079cce47fe95b0808" }
    eu-west-2                    = { linuxamd64 = "ami-03aa60e643e214902", linuxarm64 = "ami-02939fa2db1c73389", windows = "ami-0c1c249b93597f608", ubuntu2404amd64 = "ami-0eedaea2562a0b301", ubuntu2404arm64 = "ami-062b09f5b7d748666" }
    eu-south-1                   = { linuxamd64 = "ami-01c6d6c86f08bee07", linuxarm64 = "ami-0437dc2da977f5a84", windows = "ami-085ad32236af7be2a", ubuntu2404amd64 = "ami-0e01fa078eadfd094", ubuntu2404arm64 = "ami-0e52bf1c637b17edc" }
    eu-west-3                    = { linuxamd64 = "ami-075097914b329241d", linuxarm64 = "ami-0da4a8cf8aaf0ea8a", windows = "ami-04775b28128ed5411", ubuntu2404amd64 = "ami-0951d92c426deb762", ubuntu2404arm64 = "ami-030d945e071b2c813" }
    eu-north-1                   = { linuxamd64 = "ami-0f923b2d43e1ceeee", linuxarm64 = "ami-0fef3e6d586f991cc", windows = "ami-08218704d28a4aeb0", ubuntu2404amd64 = "ami-060c20cf944b9b8c6", ubuntu2404arm64 = "ami-063c8e2a21556198f" }
    sa-east-1                    = { linuxamd64 = "ami-0f0378b29af1693d2", linuxarm64 = "ami-01fa42e6c7022d598", windows = "ami-0b0f22df9c3d971af", ubuntu2404amd64 = "ami-0719502b28dabaf13", ubuntu2404arm64 = "ami-0d28c04b18b2055f8" }
    cloudformation_stack_version = "v6.71.5"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.14.0"
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
