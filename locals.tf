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
    us-east-1                    = { linuxamd64 = "ami-0a28a471ffade73ed", linuxarm64 = "ami-0ca21e2db030163c8", windows = "ami-0511282f36dba7c03" }
    us-east-2                    = { linuxamd64 = "ami-0b133681780ed6b80", linuxarm64 = "ami-01f72d52598265816", windows = "ami-0a3a621c51b332d84" }
    us-west-1                    = { linuxamd64 = "ami-06a4a8c956e549f5a", linuxarm64 = "ami-048fa9c2707625fb9", windows = "ami-060124c10ba9a97a0" }
    us-west-2                    = { linuxamd64 = "ami-073b8eb6c3ede74c0", linuxarm64 = "ami-0857007fce4d432d2", windows = "ami-082dec88543c0adb4" }
    af-south-1                   = { linuxamd64 = "ami-054ebf3023bdaacbb", linuxarm64 = "ami-0d9ade0349f898593", windows = "ami-07fe21a8d1ed91645" }
    ap-east-1                    = { linuxamd64 = "ami-0400fbe482e458d01", linuxarm64 = "ami-065a919e2b71d8c4b", windows = "ami-08e6c56ee932659dc" }
    ap-south-1                   = { linuxamd64 = "ami-0461952fb86dcfc6b", linuxarm64 = "ami-0312cd7f4714d774d", windows = "ami-0944e26f35f98bd5f" }
    ap-northeast-2               = { linuxamd64 = "ami-01a1cebf61c736dd6", linuxarm64 = "ami-023df6641171a8701", windows = "ami-03e3dc8d98d4ca34f" }
    ap-northeast-1               = { linuxamd64 = "ami-02273fabc8ce4b7fe", linuxarm64 = "ami-0d72fee333acaba0a", windows = "ami-0d1ceafdbee88961e" }
    ap-southeast-2               = { linuxamd64 = "ami-0849d039843f3d81b", linuxarm64 = "ami-0819e8397198476d5", windows = "ami-0bc70386539bc8eab" }
    ap-southeast-1               = { linuxamd64 = "ami-05f0bf0a77b021617", linuxarm64 = "ami-0c87ecd33e713881e", windows = "ami-01c844187cd616fac" }
    ca-central-1                 = { linuxamd64 = "ami-0b4db3f54378d43e6", linuxarm64 = "ami-09c1ffb242cfef1d7", windows = "ami-0ca4297e71ac96273" }
    eu-central-1                 = { linuxamd64 = "ami-04f05d6cc6977f991", linuxarm64 = "ami-01433a3acef640655", windows = "ami-0cc0eb936db40c203" }
    eu-west-1                    = { linuxamd64 = "ami-0d0935445b4795052", linuxarm64 = "ami-021ac581bb64da726", windows = "ami-09b8fdfc42f00ad6e" }
    eu-west-2                    = { linuxamd64 = "ami-0fb8e5950d2a917a0", linuxarm64 = "ami-03528fcd011a30611", windows = "ami-0f9203f8d1e5cc55c" }
    eu-south-1                   = { linuxamd64 = "ami-020f5adf0e3e78de1", linuxarm64 = "ami-071748d8bff38b0f4", windows = "ami-02d99c69d2fe91bc9" }
    eu-west-3                    = { linuxamd64 = "ami-016a5e91a3a75831c", linuxarm64 = "ami-076ec1799e8d7f4c6", windows = "ami-0df25ac0c699887d2" }
    eu-north-1                   = { linuxamd64 = "ami-091f2a774cd28cc5f", linuxarm64 = "ami-024876c0fefd84c6b", windows = "ami-0ff1c91abb3c57533" }
    sa-east-1                    = { linuxamd64 = "ami-0a10818d08f606bab", linuxarm64 = "ami-0d73117a0a14fbc3d", windows = "ami-0ad43341b016d3a3b" }
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
