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
    us-east-1                    = { linuxamd64 = "ami-058470fe36cb4dcc0", linuxarm64 = "ami-004795e76c1d561f2", windows = "ami-0be703523ef125081" }
    us-east-2                    = { linuxamd64 = "ami-0b75e6c32efdbc0c6", linuxarm64 = "ami-0986ea5b1e32704dd", windows = "ami-0f5755eb888bb2506" }
    us-west-1                    = { linuxamd64 = "ami-0a5064b7c03fb3cbe", linuxarm64 = "ami-06c21ac73254a6fc8", windows = "ami-01f39f9a9f5839daf" }
    us-west-2                    = { linuxamd64 = "ami-09cebcaed296e2064", linuxarm64 = "ami-04b9a1f8c05230921", windows = "ami-0f1545615856adcc4" }
    af-south-1                   = { linuxamd64 = "ami-05a18f96321d604cf", linuxarm64 = "ami-0856e34c684a02bde", windows = "ami-08f9a11b843bcc08b" }
    ap-east-1                    = { linuxamd64 = "ami-0f7438322165db289", linuxarm64 = "ami-042c71f5318abee61", windows = "ami-00507e4db4b49fe79" }
    ap-south-1                   = { linuxamd64 = "ami-091c6997bb8ab12d8", linuxarm64 = "ami-0a7f0c63301a0aea9", windows = "ami-00ba0a8c29e49ad31" }
    ap-northeast-2               = { linuxamd64 = "ami-02d833b43b732309c", linuxarm64 = "ami-0c60e110ccb1fcd82", windows = "ami-062ada2280b381107" }
    ap-northeast-1               = { linuxamd64 = "ami-0eeb8e01b0e06ec56", linuxarm64 = "ami-00deb4391781b9e63", windows = "ami-0a51275a20c774f85" }
    ap-southeast-2               = { linuxamd64 = "ami-0e82c41e4e430cdab", linuxarm64 = "ami-0414b88ba3b36838b", windows = "ami-03a7ab6555b15109d" }
    ap-southeast-1               = { linuxamd64 = "ami-01cacc78cde523bb6", linuxarm64 = "ami-0a2be18b1854a6fa5", windows = "ami-0bd63edb1e3c6c10f" }
    ca-central-1                 = { linuxamd64 = "ami-099d0a78472757f1d", linuxarm64 = "ami-02a1aa4c645ae5c77", windows = "ami-0554fcaa7184b2913" }
    eu-central-1                 = { linuxamd64 = "ami-0717f349a0a59988b", linuxarm64 = "ami-091f78d3079f099c2", windows = "ami-0eb2f372d511cf6be" }
    eu-west-1                    = { linuxamd64 = "ami-043cd3b2e3a4cef19", linuxarm64 = "ami-084d987a78469ba7b", windows = "ami-0774078f3dc238c8d" }
    eu-west-2                    = { linuxamd64 = "ami-0a3d1bbe5e8beab40", linuxarm64 = "ami-0a626ebe44d89220e", windows = "ami-09092cccf2b76ebdc" }
    eu-south-1                   = { linuxamd64 = "ami-0f45ce758f24c01cc", linuxarm64 = "ami-0f606ac67bbdb93f2", windows = "ami-01430fe34f7907442" }
    eu-west-3                    = { linuxamd64 = "ami-0c4d31cccf83d69d2", linuxarm64 = "ami-03e4a4957e65b06a5", windows = "ami-0bc5965d6aae05e75" }
    eu-north-1                   = { linuxamd64 = "ami-0504d480f9517c762", linuxarm64 = "ami-0e73295dd610d45b2", windows = "ami-09d23ad6ea1226a82" }
    sa-east-1                    = { linuxamd64 = "ami-011a14f911245a26d", linuxarm64 = "ami-0c656bf19371800aa", windows = "ami-0f8769b4bbfa0adbc" }
    cloudformation_stack_version = "v6.58.5"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.11.2"
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
