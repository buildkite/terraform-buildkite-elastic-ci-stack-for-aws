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

  # Region-specific AMI IDs by architecture (linux-amd64, linux-arm64, windows)
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0b97aa386cfb3803d", linuxarm64 = "ami-021b8430dc2ec97d2", windows = "ami-04924e5d0ded60346" }
    us-east-2                    = { linuxamd64 = "ami-0553e632703ac4bea", linuxarm64 = "ami-0dc5003601e19c557", windows = "ami-04ae4b7e66296f34c" }
    us-west-1                    = { linuxamd64 = "ami-07757be650e5e59ee", linuxarm64 = "ami-0cc23b7943d04b459", windows = "ami-0373a693c8acb0a70" }
    us-west-2                    = { linuxamd64 = "ami-0fe253cc692d9a59a", linuxarm64 = "ami-074abc5f14e613837", windows = "ami-0d2cad6285fa49678" }
    af-south-1                   = { linuxamd64 = "ami-004cf385e8b7163f0", linuxarm64 = "ami-0bb58f6e43a5aa652", windows = "ami-0696b616a52bd7a62" }
    ap-east-1                    = { linuxamd64 = "ami-001f827c08132976e", linuxarm64 = "ami-05747866a11e6db1e", windows = "ami-0d4540619e634cee9" }
    ap-south-1                   = { linuxamd64 = "ami-01ced0c82a6c2402c", linuxarm64 = "ami-02507ecb9f5798abd", windows = "ami-0a592080265330bd8" }
    ap-northeast-2               = { linuxamd64 = "ami-0cc66d4f824bb7460", linuxarm64 = "ami-0effe711982e37ea9", windows = "ami-07cf3cb1191a14668" }
    ap-northeast-1               = { linuxamd64 = "ami-088f69728d1c73a19", linuxarm64 = "ami-07a6de198d3d1c9e6", windows = "ami-0ee3f362eda9070ed" }
    ap-southeast-2               = { linuxamd64 = "ami-0b8ad78e6aabc523b", linuxarm64 = "ami-00f5a1e74ef9606a9", windows = "ami-0cf91007ea65626b8" }
    ap-southeast-1               = { linuxamd64 = "ami-08814f03e43149391", linuxarm64 = "ami-0474201a4b5335775", windows = "ami-0cba6acc270bbd37e" }
    ca-central-1                 = { linuxamd64 = "ami-0da7d6c5931803f6f", linuxarm64 = "ami-0b8be4b63d2c11a95", windows = "ami-034204742cdd664ca" }
    eu-central-1                 = { linuxamd64 = "ami-0fc2fb57d176fa9ee", linuxarm64 = "ami-0d563baed310ad2d9", windows = "ami-04f2214420f56ba21" }
    eu-west-1                    = { linuxamd64 = "ami-040cec997eb942f4a", linuxarm64 = "ami-0a2c1e0f1d2ae39b8", windows = "ami-0628c25a6a7739377" }
    eu-west-2                    = { linuxamd64 = "ami-0515b9a7747d562da", linuxarm64 = "ami-06b429883ba8d6cd3", windows = "ami-0c47b81bf60cac987" }
    eu-south-1                   = { linuxamd64 = "ami-0ca0a4d2dc004241a", linuxarm64 = "ami-0ee0ed0ed70a7f5ad", windows = "ami-003b4a337fb2352b9" }
    eu-west-3                    = { linuxamd64 = "ami-01db0c015f1c15e7b", linuxarm64 = "ami-0a55eebe8bb589eaf", windows = "ami-032f876de8e10003e" }
    eu-north-1                   = { linuxamd64 = "ami-0d3b51ee9737ab639", linuxarm64 = "ami-0e4386f1e931bf8a3", windows = "ami-0b4b9cfa07dbd384b" }
    sa-east-1                    = { linuxamd64 = "ami-0d0fa81939182c87f", linuxarm64 = "ami-0b855561860354efd", windows = "ami-02a345840e8f58ff0" }
    cloudformation_stack_version = "v6.69.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
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
