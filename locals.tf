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
    us-east-1                    = { linuxamd64 = "ami-0a8761f87b5075415", linuxarm64 = "ami-069b9744dc31a4407", windows = "ami-06d56bdf3babe6f68", ubuntu2404amd64 = "ami-0f816408539b8057f", ubuntu2404arm64 = "ami-00279e4ba06d7ec5d" }
    us-east-2                    = { linuxamd64 = "ami-03fa2c727b8d90736", linuxarm64 = "ami-0ca94b52998653983", windows = "ami-0a29c57690a87d3d8", ubuntu2404amd64 = "ami-03f1866612b3befa0", ubuntu2404arm64 = "ami-0f755594b149fee4f" }
    us-west-1                    = { linuxamd64 = "ami-0c20a0b63831e7ee9", linuxarm64 = "ami-0433ba89d216b5e8e", windows = "ami-0528efe01dce77137", ubuntu2404amd64 = "ami-0c34b824d1186928e", ubuntu2404arm64 = "ami-02d3ee546904adb8a" }
    us-west-2                    = { linuxamd64 = "ami-0020b15ead078031a", linuxarm64 = "ami-07c6c2ce804402066", windows = "ami-05f7662b6427b2bb1", ubuntu2404amd64 = "ami-0c4fc0ae4c5b1a08b", ubuntu2404arm64 = "ami-00b5acd521b8acc15" }
    af-south-1                   = { linuxamd64 = "ami-026a76a0aebbd0d06", linuxarm64 = "ami-0659c767b301ad52f", windows = "ami-06eb0f8ef26326d56", ubuntu2404amd64 = "ami-0f2e2db5a31c53894", ubuntu2404arm64 = "ami-000dfdaf20fe989f0" }
    ap-east-1                    = { linuxamd64 = "ami-027c29a3133b56d89", linuxarm64 = "ami-05e5dd8c83aa6be7d", windows = "ami-0397336f6208286ba", ubuntu2404amd64 = "ami-048406c822715ab48", ubuntu2404arm64 = "ami-0a3907988dec9f32c" }
    ap-south-1                   = { linuxamd64 = "ami-036aca5b64bb6014d", linuxarm64 = "ami-0a573357872072049", windows = "ami-00bf231804ec74d01", ubuntu2404amd64 = "ami-07f601113530be082", ubuntu2404arm64 = "ami-07778dc7ea01ad2b5" }
    ap-northeast-2               = { linuxamd64 = "ami-00cee2f06f404a258", linuxarm64 = "ami-052d06e4f642c8d95", windows = "ami-03cfb1d39712f9f28", ubuntu2404amd64 = "ami-0715ec72daef6f965", ubuntu2404arm64 = "ami-055078ae807d430ef" }
    ap-northeast-1               = { linuxamd64 = "ami-01ddc868826d5b538", linuxarm64 = "ami-0093f77a37db3caba", windows = "ami-077a3a4ce8e50808b", ubuntu2404amd64 = "ami-0aa89710bfba60297", ubuntu2404arm64 = "ami-00798a7256e7e2593" }
    ap-southeast-2               = { linuxamd64 = "ami-0270766b013d525e0", linuxarm64 = "ami-0ac7679854c5297d4", windows = "ami-0f64e24b4c7b827bd", ubuntu2404amd64 = "ami-0a48c9470377d9170", ubuntu2404arm64 = "ami-0cf0763928cea6561" }
    ap-southeast-1               = { linuxamd64 = "ami-0c9ea4e94644d5a12", linuxarm64 = "ami-026f5b76d508c54f4", windows = "ami-05ebd6caf79d941c4", ubuntu2404amd64 = "ami-0f75b72466d50ef38", ubuntu2404arm64 = "ami-0ef76de1309e6e3d9" }
    ca-central-1                 = { linuxamd64 = "ami-076d95e3811cb54a8", linuxarm64 = "ami-0a010c3b60db3c15c", windows = "ami-0b6f79a6ac2ebc6fa", ubuntu2404amd64 = "ami-04aecdd0e37cea1ad", ubuntu2404arm64 = "ami-002d12bd2ca4c001c" }
    eu-central-1                 = { linuxamd64 = "ami-00de4c37ac1e34c9c", linuxarm64 = "ami-0934a28aecb78f597", windows = "ami-02c254c088eaf50c0", ubuntu2404amd64 = "ami-0c07e054eb791d3e5", ubuntu2404arm64 = "ami-0612ca91c9fb8e871" }
    eu-west-1                    = { linuxamd64 = "ami-08aa2398555bc1c6a", linuxarm64 = "ami-017618f2fcd1b38ba", windows = "ami-06500d8d6ddfd314d", ubuntu2404amd64 = "ami-011c51879fec94667", ubuntu2404arm64 = "ami-0e54ea9fa569b1389" }
    eu-west-2                    = { linuxamd64 = "ami-0be396d23f088cfb1", linuxarm64 = "ami-074297966f0b9525e", windows = "ami-05a30fb2e76956982", ubuntu2404amd64 = "ami-0863688e2a3cc3244", ubuntu2404arm64 = "ami-0c4df4ae29c584feb" }
    eu-south-1                   = { linuxamd64 = "ami-02d234cd626e68bd0", linuxarm64 = "ami-04241b05da401f252", windows = "ami-03c4f953e182f7def", ubuntu2404amd64 = "ami-02d3d930bfe4c1840", ubuntu2404arm64 = "ami-09f05ceabe1185439" }
    eu-west-3                    = { linuxamd64 = "ami-02ca67d3714e83c9c", linuxarm64 = "ami-0531c8070a9748ca0", windows = "ami-0e4a8a8ba4656b590", ubuntu2404amd64 = "ami-0aa8165b4b061fc1c", ubuntu2404arm64 = "ami-09347ac4afa8232df" }
    eu-north-1                   = { linuxamd64 = "ami-0a70f51d9b4e8cad0", linuxarm64 = "ami-0ea460ed724d21c53", windows = "ami-071ff041613babada", ubuntu2404amd64 = "ami-046e4c8a8ffb4653f", ubuntu2404arm64 = "ami-0e027096a5bc2c386" }
    sa-east-1                    = { linuxamd64 = "ami-0a34213e0424488aa", linuxarm64 = "ami-09a560c16964c3936", windows = "ami-0e3e98af691ab2595", ubuntu2404amd64 = "ami-037e6de301215c444", ubuntu2404arm64 = "ami-0a0f506e100c006c3" }
    cloudformation_stack_version = "v6.71.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
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
