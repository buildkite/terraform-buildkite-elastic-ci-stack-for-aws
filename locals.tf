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
  use_custom_role_name     = var.instance_role_name != ""
  use_permissions_boundary = var.instance_role_permissions_boundary_arn != ""

  # Parse comma-separated role tags into list
  role_tag_list  = compact(split(",", var.instance_role_tags))
  role_tag_count = length(local.role_tag_list)

  use_managed_policies = length(var.managed_policy_arns) > 0


  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by architecture (linux-amd64, linux-arm64, windows)
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1      = { linuxamd64 = "ami-02bc0594bafab3192", linuxarm64 = "ami-0708d316fe0e22063", windows = "ami-0c11dfe3d59f0e26d" }
    us-east-2      = { linuxamd64 = "ami-09fdae5bcf1f89b92", linuxarm64 = "ami-0950c793ca4f19876", windows = "ami-0263bedf41e4d731b" }
    us-west-1      = { linuxamd64 = "ami-0cced7db1a2691cf8", linuxarm64 = "ami-0477db7f01f08a427", windows = "ami-075b652872ccfa1ce" }
    us-west-2      = { linuxamd64 = "ami-00f9792c70c56a13b", linuxarm64 = "ami-0173c9921ff7c6728", windows = "ami-0af2d75deadf05ae3" }
    af-south-1     = { linuxamd64 = "ami-0ed28ecedd0a9f43b", linuxarm64 = "ami-0981981465d8d8379", windows = "ami-06da60e8327849e7c" }
    ap-east-1      = { linuxamd64 = "ami-03d64bc88ac7e1f53", linuxarm64 = "ami-0ce6b0d6d82c8996b", windows = "ami-0540d38f78df3e6a6" }
    ap-south-1     = { linuxamd64 = "ami-0cd3bb320c7a424ba", linuxarm64 = "ami-0b9e32cf9465d8024", windows = "ami-0d92bc81a829bb550" }
    ap-northeast-2 = { linuxamd64 = "ami-011078b3a89b92277", linuxarm64 = "ami-02c55bb7167a76fec", windows = "ami-0041cc4456cbb0b72" }
    ap-northeast-1 = { linuxamd64 = "ami-093298945a0ef5aea", linuxarm64 = "ami-0074f3958899a7897", windows = "ami-0ef004e92a834d3f8" }
    ap-southeast-2 = { linuxamd64 = "ami-01d71daa69620bd26", linuxarm64 = "ami-063728a6a87a81ec0", windows = "ami-0aaffdf844702927e" }
    ap-southeast-1 = { linuxamd64 = "ami-098e1971d46971e92", linuxarm64 = "ami-09add4754525c8413", windows = "ami-08f465a5ef49da26e" }
    ca-central-1   = { linuxamd64 = "ami-0b9fa4b6c7e946cab", linuxarm64 = "ami-0af420e49c2f98a52", windows = "ami-0b1253d5f47986e88" }
    eu-central-1   = { linuxamd64 = "ami-0fb23a0f2ff116662", linuxarm64 = "ami-0b70a99a18baba811", windows = "ami-0ebb9cf6dc17dbd70" }
    eu-west-1      = { linuxamd64 = "ami-00c54414dfdc5160b", linuxarm64 = "ami-055f7791d9ebf3a66", windows = "ami-016c3bb5ef600dde3" }
    eu-west-2      = { linuxamd64 = "ami-09badb9f0c2acda1f", linuxarm64 = "ami-0a9ae413b27436496", windows = "ami-02fde2992afcc92be" }
    eu-south-1     = { linuxamd64 = "ami-08584df3f55523258", linuxarm64 = "ami-0493ceba25fd42ac6", windows = "ami-02e6e9b5113252b80" }
    eu-west-3      = { linuxamd64 = "ami-0ba7d0ac152f8c21f", linuxarm64 = "ami-0f1392f0a1bc6941b", windows = "ami-0593be8acc465da0f" }
    eu-north-1     = { linuxamd64 = "ami-04b21730a234bb32f", linuxarm64 = "ami-0ad6243b41b376dbc", windows = "ami-086f7f4cc126ee29f" }
    me-south-1     = { linuxamd64 = "ami-0d7769006b3098827", linuxarm64 = "ami-08b58c028fe36adb9", windows = "ami-0ed3100607f645cf3" }
    sa-east-1      = { linuxamd64 = "ami-02ad5907600361c49", linuxarm64 = "ami-09b09744576f76bca", windows = "ami-04b4a2eda06e5f7a9" }
  }

  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM instance families: Graviton (a1, c6g*, c7g*, c8g, g5g, i4g, im4gn, is4gen, m6g*, m7g*, m8g*, r6g*, r7g*, r8g, t4g, x2gd)
  is_arm_instance = contains([
    "a1", "c6g", "c6gd", "c6gn", "c7g", "c7gd", "c7gn", "c8g", "g5g",
    "i4g", "im4gn", "is4gen", "m6g", "m6gd", "m7g", "m7gd", "m8g", "m8gd",
    "r6g", "r6gd", "r7g", "r7gd", "r8g", "t4g", "x2gd"
  ], local.instance_type_family)

  # Burstable instance families: t2, t3, t3a, t4g
  is_burstable_instance = contains(["t2", "t3", "t3a", "t4g"], local.instance_type_family)

  is_windows       = var.instance_operating_system == "windows"
  ami_architecture = local.is_windows ? "windows" : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  selected_ami_id  = local.buildkite_ami_mapping[data.aws_region.current.id][local.ami_architecture]

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
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

  # Computed agent token parameter ARN (for IAM policies)
  agent_token_parameter_arn = local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"

  # Determine AMI ID from custom, parameter, or Buildkite mapping
  computed_ami_id = local.use_custom_ami ? var.image_id : (local.use_ami_parameter ? data.aws_ssm_parameter.ami[0].value : local.selected_ami_id)

  # Determine root volume device name based on OS
  root_device_name = local.use_default_volume_name ? (local.is_windows ? "/dev/sda1" : "/dev/xvda") : var.root_volume_name

  # SSH key and authorized users settings
  use_ssh_key        = var.key_name != ""
  enable_ssh_ingress = local.create_security_group && (local.use_ssh_key || var.authorized_users_url != "")

  # Cost allocation tag settings
  enable_cost_tags = var.enable_cost_allocation_tags

  # Stack naming and tagging
  stack_name_full = "${var.stack_name}-${random_id.stack_suffix.hex}"

  common_tags = {
    ManagedBy = "Terraform"
    Stack     = local.stack_name_full
  }
}
