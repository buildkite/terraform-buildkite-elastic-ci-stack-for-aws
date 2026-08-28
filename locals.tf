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
    us-east-1                    = { linuxamd64 = "ami-0706a08915b158fef", linuxarm64 = "ami-0db1704189b599489", windows = "ami-086d600e8d77f714a", ubuntu2404amd64 = "ami-0648251027ac18c49", ubuntu2404arm64 = "ami-0db25348e9f6627ac" }
    us-east-2                    = { linuxamd64 = "ami-0c0a62caf534e8b5a", linuxarm64 = "ami-09b29c1c907ccfb02", windows = "ami-077f866b6c7441022", ubuntu2404amd64 = "ami-0332babc0886d4723", ubuntu2404arm64 = "ami-070e746d106d3de28" }
    us-west-1                    = { linuxamd64 = "ami-04fdcf1584bc2e394", linuxarm64 = "ami-073423c2f4f03f7cb", windows = "ami-0c90798e224ec5b63", ubuntu2404amd64 = "ami-09850f695cc8eccf8", ubuntu2404arm64 = "ami-0e67d66e20c4da272" }
    us-west-2                    = { linuxamd64 = "ami-0e2b50e8786676df0", linuxarm64 = "ami-0ec93a6605d16d574", windows = "ami-079756f27a0584e5d", ubuntu2404amd64 = "ami-0886d0272cf53b986", ubuntu2404arm64 = "ami-0f45b19a897cc60db" }
    af-south-1                   = { linuxamd64 = "ami-0ecde5e1b27f9c64e", linuxarm64 = "ami-0a71e02bf164b1aba", windows = "ami-09bc104b77e91a7db", ubuntu2404amd64 = "ami-0bb9e590cfa26647b", ubuntu2404arm64 = "ami-0887ef3e459a2dd26" }
    ap-east-1                    = { linuxamd64 = "ami-01068be14405888ed", linuxarm64 = "ami-0caa47766d516625f", windows = "ami-0c6f6d69454af1fe2", ubuntu2404amd64 = "ami-0096f40a42319bdba", ubuntu2404arm64 = "ami-0602f059d9ca1fc3c" }
    ap-south-1                   = { linuxamd64 = "ami-03ac79cea4f7ff5fb", linuxarm64 = "ami-01485e04a9e774db0", windows = "ami-0649a782204b978be", ubuntu2404amd64 = "ami-0eed1bc089d02646b", ubuntu2404arm64 = "ami-09bea388aecac9656" }
    ap-northeast-2               = { linuxamd64 = "ami-07c91ca1b4b6eec5e", linuxarm64 = "ami-0e2b7db490e6e2400", windows = "ami-0af9b027cfc164383", ubuntu2404amd64 = "ami-05ebb7aeef4f00299", ubuntu2404arm64 = "ami-0342cab1bf43ce812" }
    ap-northeast-1               = { linuxamd64 = "ami-0e7da3070852efb1d", linuxarm64 = "ami-047f9a9588cabef12", windows = "ami-07ab3f766aa70dd81", ubuntu2404amd64 = "ami-097e4cb6ce7f17e7c", ubuntu2404arm64 = "ami-0543dcf7967fa31fe" }
    ap-southeast-2               = { linuxamd64 = "ami-04e33681b630f2281", linuxarm64 = "ami-067039403becfe51d", windows = "ami-0364fc28be965a4a1", ubuntu2404amd64 = "ami-05875143cbcd1838d", ubuntu2404arm64 = "ami-05873a7a0ae9f7e27" }
    ap-southeast-1               = { linuxamd64 = "ami-0f46922022c5600ab", linuxarm64 = "ami-03e13270d34873dec", windows = "ami-0085bee4f99160e9a", ubuntu2404amd64 = "ami-02097acdfc4072827", ubuntu2404arm64 = "ami-05ba195c322c5af06" }
    ca-central-1                 = { linuxamd64 = "ami-0fae11a8543db8ec1", linuxarm64 = "ami-0b9f5302aecab36c1", windows = "ami-0669949f4bca519e1", ubuntu2404amd64 = "ami-0eb9cb3a53522d7d5", ubuntu2404arm64 = "ami-031f5fc5dbaa8c92f" }
    eu-central-1                 = { linuxamd64 = "ami-0ae944a4580cb8385", linuxarm64 = "ami-03b5e9e386e267dff", windows = "ami-0983762285aeecfc0", ubuntu2404amd64 = "ami-04f5474a9403209b5", ubuntu2404arm64 = "ami-04e63f3466e4e60e9" }
    eu-west-1                    = { linuxamd64 = "ami-0f4a27095d5dd441b", linuxarm64 = "ami-0f9403525fafd8331", windows = "ami-0d5faa2ebb2d2a30a", ubuntu2404amd64 = "ami-044e22727b09ddb02", ubuntu2404arm64 = "ami-0f282d9e4f5fc0a2f" }
    eu-west-2                    = { linuxamd64 = "ami-0b067230ff2828f55", linuxarm64 = "ami-0993130e92c2f0acd", windows = "ami-0d209706569d34c6f", ubuntu2404amd64 = "ami-00ecb7e8d52e7ec8f", ubuntu2404arm64 = "ami-0f352ac88fbe758c5" }
    eu-south-1                   = { linuxamd64 = "ami-01d1a5ff1cb593419", linuxarm64 = "ami-08c647f17648c4167", windows = "ami-04e08117dde399013", ubuntu2404amd64 = "ami-0ace0515cfea34f74", ubuntu2404arm64 = "ami-0a39519db3db41686" }
    eu-west-3                    = { linuxamd64 = "ami-055902c9d10dd196a", linuxarm64 = "ami-0bfd70f2917f7e97a", windows = "ami-0a49c015713745a92", ubuntu2404amd64 = "ami-02040b06b5a90d6b6", ubuntu2404arm64 = "ami-005aa4d4cd87257e8" }
    eu-north-1                   = { linuxamd64 = "ami-0e123ab96b3e4afe9", linuxarm64 = "ami-06b0af52e271e4c0e", windows = "ami-00f72dedd0d94eb67", ubuntu2404amd64 = "ami-03a00b6d2897f8bc3", ubuntu2404arm64 = "ami-0716f20b47c7421c2" }
    sa-east-1                    = { linuxamd64 = "ami-0225cb390c5c272f6", linuxarm64 = "ami-069287f9bcfab8cfd", windows = "ami-0aaf16f27cf4db2ac", ubuntu2404amd64 = "ami-0b76a227d4c48f756", ubuntu2404arm64 = "ami-0c03cb242115da4e4" }
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
