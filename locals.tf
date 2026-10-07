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
    us-east-1                    = { linuxamd64 = "ami-0e204e732d353c3b8", linuxarm64 = "ami-07547890ce10874a7", windows = "ami-0b9570cde73405f37", ubuntu2404amd64 = "ami-09e518611b2060109", ubuntu2404arm64 = "ami-00356e8104fc7a26d" }
    us-east-2                    = { linuxamd64 = "ami-0a6c80c2dd7e9479a", linuxarm64 = "ami-03c31655c34e3c749", windows = "ami-0e05dfff2d22b1d17", ubuntu2404amd64 = "ami-056ac4c4442480c74", ubuntu2404arm64 = "ami-0678202573a70c159" }
    us-west-1                    = { linuxamd64 = "ami-0a13f818e158465a5", linuxarm64 = "ami-056c5f5aed0d2faa0", windows = "ami-015de7fedc46b799d", ubuntu2404amd64 = "ami-0f7afc5a4ab5be4ad", ubuntu2404arm64 = "ami-013d5f34243d460ab" }
    us-west-2                    = { linuxamd64 = "ami-016fd87d16414620a", linuxarm64 = "ami-093729a896989d9a4", windows = "ami-069652b421f15ebc8", ubuntu2404amd64 = "ami-0eaa0ccaa6f4c0e5d", ubuntu2404arm64 = "ami-00447e8843d5e2d0c" }
    af-south-1                   = { linuxamd64 = "ami-0d80efa11a3e55a16", linuxarm64 = "ami-0c6bb591aef6aa648", windows = "ami-00711c286b8dc9234", ubuntu2404amd64 = "ami-0ae1292d97c367a76", ubuntu2404arm64 = "ami-09f7b9fdd0f456cfc" }
    ap-east-1                    = { linuxamd64 = "ami-0362e87be48fb4f1c", linuxarm64 = "ami-08fb4b4b240635b8d", windows = "ami-084e692b6b5c6aa08", ubuntu2404amd64 = "ami-07b13ace23407c02c", ubuntu2404arm64 = "ami-0269fc31872be91ff" }
    ap-south-1                   = { linuxamd64 = "ami-076c6b18b92f6d14f", linuxarm64 = "ami-054fbb68e856c10b6", windows = "ami-06c99d743f4e35cfc", ubuntu2404amd64 = "ami-022691ce9c56066f6", ubuntu2404arm64 = "ami-0bd7ec7d7e34252c2" }
    ap-northeast-2               = { linuxamd64 = "ami-015c2f0f919c55cf5", linuxarm64 = "ami-0fd55e2035e7e6780", windows = "ami-0552cf64659031ab1", ubuntu2404amd64 = "ami-0f6197dd8cc86ba56", ubuntu2404arm64 = "ami-050347ac765ea96cf" }
    ap-northeast-1               = { linuxamd64 = "ami-0a8cb67486772b69f", linuxarm64 = "ami-04ce68e3d2b8c69aa", windows = "ami-0ef776c7d9277cdcc", ubuntu2404amd64 = "ami-029db3ef678cf2fa8", ubuntu2404arm64 = "ami-081a9e85496263bf1" }
    ap-southeast-2               = { linuxamd64 = "ami-0f7ae8d7db082f461", linuxarm64 = "ami-03a4075004c9d8702", windows = "ami-0d8b8e32768104444", ubuntu2404amd64 = "ami-0706f6fba42505f79", ubuntu2404arm64 = "ami-0f162143b280729a7" }
    ap-southeast-1               = { linuxamd64 = "ami-0fc136c08f4bdf207", linuxarm64 = "ami-01c7e8a9ea82eca5d", windows = "ami-00a3e63314591bd5d", ubuntu2404amd64 = "ami-0a78ca39de8bc5adb", ubuntu2404arm64 = "ami-065b8eb4206a386f9" }
    ca-central-1                 = { linuxamd64 = "ami-07524ecc7266405d8", linuxarm64 = "ami-069b75597bf55c0f0", windows = "ami-0e4edbb93d2f39c1a", ubuntu2404amd64 = "ami-0048b26d9ee1dd998", ubuntu2404arm64 = "ami-0d4d4531e1b8c62cf" }
    eu-central-1                 = { linuxamd64 = "ami-08af33a3c26838835", linuxarm64 = "ami-07d80432f4ed17120", windows = "ami-0ae0766893afc09e7", ubuntu2404amd64 = "ami-0e3173996845d9a02", ubuntu2404arm64 = "ami-00207aabff0f0d25c" }
    eu-west-1                    = { linuxamd64 = "ami-0dddf21a5413eb6b5", linuxarm64 = "ami-032ab0470af6a91f5", windows = "ami-0ca9db3bbc64c1836", ubuntu2404amd64 = "ami-00cd567cd408f25ad", ubuntu2404arm64 = "ami-092561d76c8936e70" }
    eu-west-2                    = { linuxamd64 = "ami-08f93893c470eb853", linuxarm64 = "ami-09f8fdbee0a81f216", windows = "ami-0efcea69e1a946b16", ubuntu2404amd64 = "ami-0bf4a73a059b94c68", ubuntu2404arm64 = "ami-00d5e4bcc874ef7b8" }
    eu-south-1                   = { linuxamd64 = "ami-07241a876465187e3", linuxarm64 = "ami-0cfeb79dfa67ee6ac", windows = "ami-074e6e61b3955ec46", ubuntu2404amd64 = "ami-0c5fbc351d894b39f", ubuntu2404arm64 = "ami-076a56bafa01cd4d9" }
    eu-west-3                    = { linuxamd64 = "ami-0a59024bd5a3d9a07", linuxarm64 = "ami-01b949f96a1a4193b", windows = "ami-045253b01ee40bdba", ubuntu2404amd64 = "ami-09c4b9de1989479f6", ubuntu2404arm64 = "ami-07a5513483557406f" }
    eu-north-1                   = { linuxamd64 = "ami-08e0397877026cdfb", linuxarm64 = "ami-047836ec6c87bfe68", windows = "ami-0bacbfd2a91055c93", ubuntu2404amd64 = "ami-0dda1dc3f5965556d", ubuntu2404arm64 = "ami-0624644330f1910fc" }
    sa-east-1                    = { linuxamd64 = "ami-02d506b8c8276dbb7", linuxarm64 = "ami-07f51dc2fde67cc7f", windows = "ami-0e8f830828f70409b", ubuntu2404amd64 = "ami-09347ac5c2a62732c", ubuntu2404arm64 = "ami-0690a6039cf63101c" }
    cloudformation_stack_version = "v7.3.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.15.0"
  # Created and updated by the scaler itself, as in the upstream scaler template
  scaler_last_scale_in_parameter = "/buildkite-agent-scaler/${local.stack_name_full}/last-scale-in"
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
