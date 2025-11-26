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
    af-south-1                   = { linuxamd64 = "ami-09f12bdfed8adc00d", linuxarm64 = "ami-0a32d4e9b82f0acd4", windows = "ami-056e86058419159b6" }
    ap-east-1                    = { linuxamd64 = "ami-07d38217e96fe86b9", linuxarm64 = "ami-04368ee68465254a2", windows = "ami-0905a6d36e3bc803e" }
    ap-northeast-1               = { linuxamd64 = "ami-039eafaa5fed73aa6", linuxarm64 = "ami-07b3625c80ceed388", windows = "ami-0607cd6b7b799f51f" }
    ap-northeast-2               = { linuxamd64 = "ami-06886427083d198d9", linuxarm64 = "ami-03d018abe6a2ada09", windows = "ami-04e3e722107fe542a" }
    ap-south-1                   = { linuxamd64 = "ami-0e86b219384e78fd1", linuxarm64 = "ami-0daf7c2e983572728", windows = "ami-0279c0db51700cd28" }
    ap-southeast-1               = { linuxamd64 = "ami-061e555493785d98f", linuxarm64 = "ami-02507f79dc0b98fc7", windows = "ami-0c3d1212d9bf53ef3" }
    ap-southeast-2               = { linuxamd64 = "ami-045c4ce4027dbd754", linuxarm64 = "ami-0310f04caf8d64b88", windows = "ami-0585dbdbc2731fe3c" }
    ca-central-1                 = { linuxamd64 = "ami-01c3042fbc54bc609", linuxarm64 = "ami-09fdb2395f26147f8", windows = "ami-0fb5944226d9a4c42" }
    eu-central-1                 = { linuxamd64 = "ami-043853b262b01aca6", linuxarm64 = "ami-0589e7c7741224340", windows = "ami-0171b93df46bf3965" }
    eu-north-1                   = { linuxamd64 = "ami-083c0a2f8996f0986", linuxarm64 = "ami-0b843e25d7e106309", windows = "ami-0a396ae89e58150b9" }
    eu-south-1                   = { linuxamd64 = "ami-079e85d4bb823980c", linuxarm64 = "ami-0157ac35eb7f05e1a", windows = "ami-01ebc449d1de2d48e" }
    eu-west-1                    = { linuxamd64 = "ami-04364adbdaa046524", linuxarm64 = "ami-004a2062db301f553", windows = "ami-09135d3d6bcec1c40" }
    eu-west-2                    = { linuxamd64 = "ami-0b0e3d64485c8e399", linuxarm64 = "ami-06c6cfc3cadb7fd73", windows = "ami-0d77a9193a91c3c9a" }
    eu-west-3                    = { linuxamd64 = "ami-0786a08e5a7c33013", linuxarm64 = "ami-0e062d7549486d83c", windows = "ami-00c7e7198a8d6ea37" }
    me-south-1                   = { linuxamd64 = "ami-0ecc5450fb6c47e9a", linuxarm64 = "ami-0c78f4ec9bee1daad", windows = "ami-01a190e1e5222f5ac" }
    sa-east-1                    = { linuxamd64 = "ami-0a8153dfb0ffd760a", linuxarm64 = "ami-04c6df7acf24b23b5", windows = "ami-0bfae073c5079cf5c" }
    us-east-1                    = { linuxamd64 = "ami-0c40e8c677fb0fcbc", linuxarm64 = "ami-070e8c440c1251fcf", windows = "ami-0ecc3286e70339c16" }
    us-east-2                    = { linuxamd64 = "ami-0f37587d540d45278", linuxarm64 = "ami-0def53cd59b1b3057", windows = "ami-0a250d0aefa4e612d" }
    us-west-1                    = { linuxamd64 = "ami-0782d2a0e9985d71d", linuxarm64 = "ami-09b6baced96da0637", windows = "ami-065565414e3157956" }
    us-west-2                    = { linuxamd64 = "ami-07e9ecdeb7ba71dcb", linuxarm64 = "ami-0bd76426bf507d6d6", windows = "ami-061e63650524ea6a6" }
    cloudformation_stack_version = "v6.49.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"

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
