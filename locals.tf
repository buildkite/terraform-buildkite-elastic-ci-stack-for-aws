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
    us-east-1                    = { linuxamd64 = "ami-0de49a21741929949", linuxarm64 = "ami-0f14cfc0f177eb5f0", windows = "ami-03ee4691f06d0c679" }
    us-east-2                    = { linuxamd64 = "ami-05b2a860087ed2796", linuxarm64 = "ami-0383a457da97fd6f7", windows = "ami-0ca28d494470868d6" }
    us-west-1                    = { linuxamd64 = "ami-0abea85be04067369", linuxarm64 = "ami-0b5a6da73ae7981bb", windows = "ami-0e006c53ea5daaae2" }
    us-west-2                    = { linuxamd64 = "ami-0443018345ee1aeea", linuxarm64 = "ami-0a10fea95c7bd562c", windows = "ami-0583fb0d1644f9a8a" }
    af-south-1                   = { linuxamd64 = "ami-08ef7051f4665d3da", linuxarm64 = "ami-05394832c3fcc8e88", windows = "ami-0e943a0196e114957" }
    ap-east-1                    = { linuxamd64 = "ami-0f5c021047842fa56", linuxarm64 = "ami-0311ddd5fab4eb754", windows = "ami-09c2b4161628de941" }
    ap-south-1                   = { linuxamd64 = "ami-023a3356ef21a7c47", linuxarm64 = "ami-065f91be368b8b4cc", windows = "ami-0a160da4488683409" }
    ap-northeast-2               = { linuxamd64 = "ami-05832931ad49e7f3d", linuxarm64 = "ami-0a0496b083953d199", windows = "ami-051f2798207c130cc" }
    ap-northeast-1               = { linuxamd64 = "ami-0022df1b0194415ad", linuxarm64 = "ami-0c4beec7b8d5bf06a", windows = "ami-0b8aa3fec215349c2" }
    ap-southeast-2               = { linuxamd64 = "ami-07b6d04da5b00bc33", linuxarm64 = "ami-0a28a84f02efadbb2", windows = "ami-0ff0d7eff528e0d4c" }
    ap-southeast-1               = { linuxamd64 = "ami-08f08eeeb7576e10e", linuxarm64 = "ami-0dedf8d95be3d2326", windows = "ami-0cd60165a7820e706" }
    ca-central-1                 = { linuxamd64 = "ami-060ccda7f3849f08b", linuxarm64 = "ami-0acd3225d59eb1dec", windows = "ami-0b9e532a1bb75118c" }
    eu-central-1                 = { linuxamd64 = "ami-0b5d6d65b4e539fcb", linuxarm64 = "ami-0abda04004b955162", windows = "ami-06fb3c25b37635070" }
    eu-west-1                    = { linuxamd64 = "ami-08d5c4fac66464d5f", linuxarm64 = "ami-01a0e00e95b6d2003", windows = "ami-0b8a6276f1bf325f6" }
    eu-west-2                    = { linuxamd64 = "ami-0500304b238b8cc11", linuxarm64 = "ami-0b17ee7c81a16e875", windows = "ami-010b166460993f103" }
    eu-south-1                   = { linuxamd64 = "ami-0e16ae8d76d4533b7", linuxarm64 = "ami-07fee7c221b476554", windows = "ami-0d4f7e0517e65b957" }
    eu-west-3                    = { linuxamd64 = "ami-0d249394a0f152739", linuxarm64 = "ami-0f0ee2f90ea7a0dec", windows = "ami-023af28c8c9e54b0a" }
    eu-north-1                   = { linuxamd64 = "ami-0d4c921afdfd0faeb", linuxarm64 = "ami-0e38045ac003b6216", windows = "ami-0a1adfe118b245c67" }
    sa-east-1                    = { linuxamd64 = "ami-089784dda0d05ee6e", linuxarm64 = "ami-0150a151b82c4cfc5", windows = "ami-05de0ee1e41538853" }
    cloudformation_stack_version = "v6.63.0"
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
