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
  create_vpc            = var.network_config.vpc_id == ""
  create_security_group = length(var.network_config.security_group_ids) == 0
  use_custom_azs        = var.network_config.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.agent_config.enable_secrets_plugin && var.s3_config.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.s3_config.secrets_bucket_encryption
  use_existing_secrets  = var.s3_config.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.s3_config.artifacts_bucket != ""

  # Instance role, permissions boundary, and policy settings
  use_custom_role_name     = var.security_config.instance_role_name != ""
  use_permissions_boundary = var.security_config.instance_role_permissions_boundary_arn != ""

  # Parse comma-separated role tags into list
  role_tag_list  = compact(split(",", var.security_config.instance_role_tags))
  role_tag_count = length(local.role_tag_list)

  use_managed_policies = length(var.security_config.managed_policy_arns) > 0


  # Image ID selection and parameter store settings
  use_custom_ami    = var.instance_config.image_id != ""
  use_ami_parameter = var.instance_config.image_id_parameter != ""

  # Region-specific AMI IDs by architecture (linux-amd64, linux-arm64, windows)
  buildkite_amis = {
    us-east-1      = { linuxamd64 = "ami-0f18d34a51beb5aef", linuxarm64 = "ami-0b91bc41649d5ca55", windows = "ami-0621e20b1f2820c5d" }
    us-east-2      = { linuxamd64 = "ami-0b944abcfc3c17f1d", linuxarm64 = "ami-0c680c91c55e3eeeb", windows = "ami-0c7e26cf95fa31800" }
    us-west-1      = { linuxamd64 = "ami-0895ee398b9817c9c", linuxarm64 = "ami-0e664535a2f850f6b", windows = "ami-028475a192375f131" }
    us-west-2      = { linuxamd64 = "ami-0b24c939ef13fee82", linuxarm64 = "ami-05625238edbb1d2b3", windows = "ami-03acfcdb22ed01963" }
    af-south-1     = { linuxamd64 = "ami-0256a74e88bc553ba", linuxarm64 = "ami-05ec95f6d15a2fc33", windows = "ami-01bdbb329d22cafff" }
    ap-east-1      = { linuxamd64 = "ami-07d9bf32d5100c3f8", linuxarm64 = "ami-0e2a78ba57ce7cc6e", windows = "ami-069d0e352866d75b3" }
    ap-south-1     = { linuxamd64 = "ami-044623c52b6458339", linuxarm64 = "ami-0cf9b75e956cbf14a", windows = "ami-051c2fd4cab0587e2" }
    ap-northeast-2 = { linuxamd64 = "ami-0d1a6d61d7dd84702", linuxarm64 = "ami-090bde9860f76a426", windows = "ami-00eb6068f81652ef2" }
    ap-northeast-1 = { linuxamd64 = "ami-04d6256985896b98e", linuxarm64 = "ami-0bb059d99aca19c06", windows = "ami-0fbb021c6ceaed4a3" }
    ap-southeast-2 = { linuxamd64 = "ami-0456cee00c93fdcc7", linuxarm64 = "ami-09fe645781067ef90", windows = "ami-090942c78f2bf796d" }
    ap-southeast-1 = { linuxamd64 = "ami-04e77c385eefe0760", linuxarm64 = "ami-03df97088b597180c", windows = "ami-02e1fe20c2609a436" }
    ca-central-1   = { linuxamd64 = "ami-01d13fe01fe8eead5", linuxarm64 = "ami-00100ded7d16e211f", windows = "ami-0c811490e84a92bf7" }
    eu-central-1   = { linuxamd64 = "ami-08f3e7dd7a61d665e", linuxarm64 = "ami-08b86cd8f64b583ed", windows = "ami-0bac75954d63d1790" }
    eu-west-1      = { linuxamd64 = "ami-00b091179695e1844", linuxarm64 = "ami-071ead7c96734d8cc", windows = "ami-0a7bd40719eea3525" }
    eu-west-2      = { linuxamd64 = "ami-05cb8964c3cd95233", linuxarm64 = "ami-0da80d8390a3d1dd9", windows = "ami-09c24b04a3e098473" }
    eu-south-1     = { linuxamd64 = "ami-0439dbb93058245e2", linuxarm64 = "ami-09a596f82d768fa2d", windows = "ami-04c1ae67d843f7a81" }
    eu-west-3      = { linuxamd64 = "ami-0022e4b225a10747e", linuxarm64 = "ami-08a6af7a821474d98", windows = "ami-0e69a1e45b443c1c0" }
    eu-north-1     = { linuxamd64 = "ami-0760989aed7656442", linuxarm64 = "ami-082af41ac0800a729", windows = "ami-0a60dc6f0e53a050c" }
    me-south-1     = { linuxamd64 = "ami-094494c464906a4c2", linuxarm64 = "ami-0a652dd035da545fc", windows = "ami-0ab2e1fbbe23391b5" }
    sa-east-1      = { linuxamd64 = "ami-0810d9d245a3f8bf6", linuxarm64 = "ami-07675f2879bc622c6", windows = "ami-000fd75fe2dc6375c" }
  }

  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_config.instance_types)[0])[0]

  # ARM instance families: Graviton (a1, c6g*, c7g*, c8g, g5g, i4g, im4gn, is4gen, m6g*, m7g*, m8g*, r6g*, r7g*, r8g, t4g, x2gd)
  is_arm_instance = contains([
    "a1", "c6g", "c6gd", "c6gn", "c7g", "c7gd", "c7gn", "c8g", "g5g",
    "i4g", "im4gn", "is4gen", "m6g", "m6gd", "m7g", "m7gd", "m8g", "m8gd",
    "r6g", "r6gd", "r7g", "r7gd", "r8g", "t4g", "x2gd"
  ], local.instance_type_family)

  # Burstable instance families: t2, t3, t3a, t4g
  is_burstable_instance = contains(["t2", "t3", "t3a", "t4g"], local.instance_type_family)

  is_windows       = var.instance_config.instance_operating_system == "windows"
  ami_architecture = local.is_windows ? "windows" : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  selected_ami_id  = local.buildkite_amis[data.aws_region.current.id][local.ami_architecture]

  # Instance naming and timeout settings
  use_default_timeout      = var.autoscaling.instance_creation_timeout == ""
  use_custom_name          = var.instance_config.instance_name != ""
  has_variable_size        = var.autoscaling.max_size != var.autoscaling.min_size
  enable_scheduled_scaling = var.autoscaling.enable_scheduled_scaling

  # EBS volume type detection and device naming
  use_default_volume_name = var.storage_config.root_volume_name == ""
  is_gp3_volume           = var.storage_config.root_volume_type == "gp3"
  supports_iops           = contains(["io1", "io2", "gp3"], var.storage_config.root_volume_type)

  # Container registry access settings
  enable_ecr             = var.docker_config.ecr_access_policy != "none"
  enable_ecr_pullthrough = contains(["readonly-pullthrough", "poweruser-pullthrough"], var.docker_config.ecr_access_policy)

  # Buildkite agent token and parameter store settings
  use_custom_token_path    = var.agent_config.token_parameter_store_path != ""
  use_custom_token_kms     = var.agent_config.token_parameter_store_kms_key != ""
  create_token_parameter   = var.agent_config.token_parameter_store_path == ""
  enable_graceful_shutdown = var.agent_config.enable_graceful_shutdown

  # KMS key settings for pipeline signature verification
  use_existing_signing_key = var.pipeline_signing_config.kms_key_id != ""
  create_signing_key       = var.pipeline_signing_config.kms_key_id == "" && var.pipeline_signing_config.kms_key_spec != "none"
  has_signing_key          = local.create_signing_key || local.use_existing_signing_key
  signing_key_full_access  = var.pipeline_signing_config.kms_access == "sign-and-verify"
  signing_key_is_arn       = startswith(var.pipeline_signing_config.kms_key_id, "arn:")

  # Computed signing key ARN (for use in templates)
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_config.kms_key_id

  # Computed agent token parameter ARN (for IAM policies)
  agent_token_parameter_arn = local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter/${var.agent_config.token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"

  # Determine AMI ID from custom, parameter, or Buildkite mapping
  computed_ami_id = local.use_custom_ami ? var.instance_config.image_id : (local.use_ami_parameter ? data.aws_ssm_parameter.ami[0].value : local.selected_ami_id)

  # Determine root volume device name based on OS
  root_device_name = local.use_default_volume_name ? (local.is_windows ? "/dev/sda1" : "/dev/xvda") : var.storage_config.root_volume_name

  # SSH key and authorized users settings
  use_ssh_key        = var.security_config.ssh_key_name != ""
  enable_ssh_ingress = local.create_security_group && (local.use_ssh_key || var.security_config.authorized_users_url != "")

  # Cost allocation tag settings
  enable_cost_tags = var.cost_config.enable_allocation_tags

  # Stack naming and tagging
  stack_name_full = "${var.stack_name}-${random_id.stack_suffix.hex}"

  common_tags = {
    ManagedBy = "Terraform"
    Stack     = local.stack_name_full
  }
}