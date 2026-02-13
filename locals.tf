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
  use_custom_iam_role      = var.instance_role_arn != ""
  use_custom_role_name     = var.instance_role_name != ""
  use_permissions_boundary = var.instance_role_permissions_boundary_arn != ""

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

  # Region-specific AMI IDs by architecture (linux-amd64, linux-arm64, windows)
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    af-south-1                   = { linuxamd64 = "ami-03da1ed23fb5f24f4", linuxarm64 = "ami-01632c7ebe3cb69a8", windows = "ami-05a265d44bded4558" }
    ap-east-1                    = { linuxamd64 = "ami-036939dc2fc097614", linuxarm64 = "ami-0980ec90ce3235bc0", windows = "ami-0d757bf9326c45899" }
    ap-northeast-1               = { linuxamd64 = "ami-03df1504787bd473b", linuxarm64 = "ami-0a38d0d77bd663561", windows = "ami-0bc77388a2254f908" }
    ap-northeast-2               = { linuxamd64 = "ami-0d92be3c3af68ee88", linuxarm64 = "ami-08e571ad5dd1de8b7", windows = "ami-0292e61065c576937" }
    ap-south-1                   = { linuxamd64 = "ami-0d56d45499f42842a", linuxarm64 = "ami-0e99a0b0bb5f54be2", windows = "ami-0153f58927f026cf0" }
    ap-southeast-1               = { linuxamd64 = "ami-0aae53c58a6af46b3", linuxarm64 = "ami-0fd2ff24d3df5df67", windows = "ami-0a30b8666f2ba30a7" }
    ap-southeast-2               = { linuxamd64 = "ami-0b17e30a774ace088", linuxarm64 = "ami-08184c26f91266a36", windows = "ami-0bd9558d6b121ad6f" }
    ca-central-1                 = { linuxamd64 = "ami-03fe82f79a31c7588", linuxarm64 = "ami-0614e82b44ac93c79", windows = "ami-0c03c1ac0653c8ed1" }
    eu-central-1                 = { linuxamd64 = "ami-03e021c99b76df54f", linuxarm64 = "ami-051ed6cd8cc22dde6", windows = "ami-0796e63616b040931" }
    eu-north-1                   = { linuxamd64 = "ami-0f4d7f20f49a35a09", linuxarm64 = "ami-01f535c7337526a63", windows = "ami-0db1a4ce24038ca05" }
    eu-south-1                   = { linuxamd64 = "ami-0862452a1fe3f2786", linuxarm64 = "ami-02c6b466de9e75430", windows = "ami-062f233b9fa638c9b" }
    eu-west-1                    = { linuxamd64 = "ami-0829c65de8f46e097", linuxarm64 = "ami-005be640e08a86e78", windows = "ami-07ae62399b00f8395" }
    eu-west-2                    = { linuxamd64 = "ami-093906f68660a1064", linuxarm64 = "ami-077d41bced6fc7484", windows = "ami-025fb6f657b64ae77" }
    eu-west-3                    = { linuxamd64 = "ami-04b8ca1e9b02d144a", linuxarm64 = "ami-07540ea125516fb21", windows = "ami-0ca960086c17781a7" }
    me-south-1                   = { linuxamd64 = "ami-0946d9f87071d38d4", linuxarm64 = "ami-070343da272c2c8f2", windows = "ami-0092c625cf5b3578c" }
    sa-east-1                    = { linuxamd64 = "ami-055206ccf2a5993dd", linuxarm64 = "ami-0a3218f7d1680c0e3", windows = "ami-0294e077cd168a9be" }
    us-east-1                    = { linuxamd64 = "ami-0585aaf73b04ba976", linuxarm64 = "ami-04564bb4c1dd3e6bd", windows = "ami-0926cba71970cfd08" }
    us-east-2                    = { linuxamd64 = "ami-0186446e8b964e79b", linuxarm64 = "ami-0cc37cd0901f972eb", windows = "ami-0c4101a9841356d93" }
    us-west-1                    = { linuxamd64 = "ami-01c1e2be6b8c7e254", linuxarm64 = "ami-0977d353f57a8b190", windows = "ami-0d9c9bb9d9b72db5c" }
    us-west-2                    = { linuxamd64 = "ami-00682aba650a40d4b", linuxarm64 = "ami-054f26fed56926466", windows = "ami-00ff1f19c9266b43d" }
    cloudformation_stack_version = "v6.56.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.11.0"
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
