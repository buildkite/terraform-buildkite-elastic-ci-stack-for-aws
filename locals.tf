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
    us-east-1                    = { linuxamd64 = "ami-0a501457519f0797c", linuxarm64 = "ami-0e8a3f4eab5eed80d", windows = "ami-081cbdbbd7d824e3d", ubuntu2404amd64 = "ami-02a7ba8ce51c0b886", ubuntu2404arm64 = "ami-03d9fe9a95630d20e" }
    us-east-2                    = { linuxamd64 = "ami-0497f607a363b413d", linuxarm64 = "ami-092891d04f1882353", windows = "ami-013a2cddb94dc74db", ubuntu2404amd64 = "ami-0727328cecd422426", ubuntu2404arm64 = "ami-00fcc5e2bcb3220d5" }
    us-west-1                    = { linuxamd64 = "ami-033dfaf38fd18afc9", linuxarm64 = "ami-0cc3c5f7a6cefb103", windows = "ami-090637e2baccbf454", ubuntu2404amd64 = "ami-0e2adfb0493d9eb74", ubuntu2404arm64 = "ami-0a28eb85df69efe7a" }
    us-west-2                    = { linuxamd64 = "ami-05e1c2676974f1c7f", linuxarm64 = "ami-0579990ccf3e2f957", windows = "ami-0551227c0466c4fc2", ubuntu2404amd64 = "ami-0aea25a976c05ac49", ubuntu2404arm64 = "ami-09faaab6da2afe751" }
    af-south-1                   = { linuxamd64 = "ami-03efbce7093b5f363", linuxarm64 = "ami-099485e32443382ad", windows = "ami-09a699c4188c067ec", ubuntu2404amd64 = "ami-02af6cf580299cdd2", ubuntu2404arm64 = "ami-061099a4ff1ebcec3" }
    ap-east-1                    = { linuxamd64 = "ami-032ef720801c4bf3a", linuxarm64 = "ami-0ec49140171f0eda8", windows = "ami-01f971d70ec2d6c60", ubuntu2404amd64 = "ami-0450e4c0c3699e113", ubuntu2404arm64 = "ami-0296ff1a921a733fa" }
    ap-south-1                   = { linuxamd64 = "ami-0953797818cf5cdc8", linuxarm64 = "ami-0c5118f82a17e2b73", windows = "ami-03ea11e1ba7bda54f", ubuntu2404amd64 = "ami-02406eeb43dc6661a", ubuntu2404arm64 = "ami-0610ba6e877c87fe0" }
    ap-northeast-2               = { linuxamd64 = "ami-00991d592ff859df1", linuxarm64 = "ami-0caa78fc86ee9c46e", windows = "ami-00e38664bc4d4cbe1", ubuntu2404amd64 = "ami-00722537430b3ad57", ubuntu2404arm64 = "ami-00a3f30f5578704c5" }
    ap-northeast-1               = { linuxamd64 = "ami-00d1485fef553b1d8", linuxarm64 = "ami-0776cb62ae6b8abd7", windows = "ami-0d4639af239abdf3b", ubuntu2404amd64 = "ami-03e57ffdf4026b0d5", ubuntu2404arm64 = "ami-0f4a1dc6c27421534" }
    ap-southeast-2               = { linuxamd64 = "ami-05866fb1704780614", linuxarm64 = "ami-0897dc56c2683c463", windows = "ami-0a03a8696925123fa", ubuntu2404amd64 = "ami-0ef47170a0d277e2b", ubuntu2404arm64 = "ami-0b8011a8f9a41f7e0" }
    ap-southeast-1               = { linuxamd64 = "ami-0da0ce74c39855dff", linuxarm64 = "ami-005a2b8520e03e6ae", windows = "ami-0b5a7242731c55a1d", ubuntu2404amd64 = "ami-0b6b19deb061b6d14", ubuntu2404arm64 = "ami-018afbc8d21a9fb5b" }
    ca-central-1                 = { linuxamd64 = "ami-0cc68ae0637a59967", linuxarm64 = "ami-0c56d58e60e7efcbf", windows = "ami-0cf9984743908bade", ubuntu2404amd64 = "ami-03fc21431bbe332f4", ubuntu2404arm64 = "ami-0f287f1a9dac3099b" }
    eu-central-1                 = { linuxamd64 = "ami-026b9f2271241f4b7", linuxarm64 = "ami-077c2a965d60721e3", windows = "ami-0b783dc6f845260f1", ubuntu2404amd64 = "ami-04745bc55e73add9c", ubuntu2404arm64 = "ami-01090b15f2e804ed5" }
    eu-west-1                    = { linuxamd64 = "ami-0ad4b7c4873f59e39", linuxarm64 = "ami-0b0b178bf4b9cbb56", windows = "ami-0af72ea01f4ed37f1", ubuntu2404amd64 = "ami-03b6c9fa4bd06f4cb", ubuntu2404arm64 = "ami-0105fa592e66e1634" }
    eu-west-2                    = { linuxamd64 = "ami-0caa181a14558e8a8", linuxarm64 = "ami-03dddd414d43d2a55", windows = "ami-02e562b8f21a98af6", ubuntu2404amd64 = "ami-030d5ca8f09ad96bb", ubuntu2404arm64 = "ami-01ae0a0351b7accd7" }
    eu-south-1                   = { linuxamd64 = "ami-06ddb4679ef7f291a", linuxarm64 = "ami-06f95eaf7fc5d0b09", windows = "ami-0c308b64a829ad49a", ubuntu2404amd64 = "ami-0f2cbe127d14399a9", ubuntu2404arm64 = "ami-0b1e0a42ad07db443" }
    eu-west-3                    = { linuxamd64 = "ami-07c976e0ca344d7cf", linuxarm64 = "ami-019785a36720e44a6", windows = "ami-09afafa43a7b2f3f0", ubuntu2404amd64 = "ami-0c9195bbad6a269c4", ubuntu2404arm64 = "ami-0dc8febdb5286b69a" }
    eu-north-1                   = { linuxamd64 = "ami-0468815fd2217c300", linuxarm64 = "ami-0591837bf3d20c243", windows = "ami-0bb470f9455f7b9e2", ubuntu2404amd64 = "ami-0b803d02bfe39bf2e", ubuntu2404arm64 = "ami-037fa17aabeefcfd6" }
    sa-east-1                    = { linuxamd64 = "ami-063d1e52f5412e66f", linuxarm64 = "ami-0af8d9ece2f2a799a", windows = "ami-0d7decfeb691d4d46", ubuntu2404amd64 = "ami-080d348b657aa6eb1", ubuntu2404arm64 = "ami-08bbdb51667704dd6" }
    cloudformation_stack_version = "v6.71.3"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.13.0"
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
