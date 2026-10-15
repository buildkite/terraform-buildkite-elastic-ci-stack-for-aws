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
  create_vpc            = var.create_vpc != null ? var.create_vpc : var.vpc_id == ""
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
    us-east-1                    = { linuxamd64 = "ami-024cec91cf62d9f88", linuxarm64 = "ami-037cd9161b0cb6ff8", windows = "ami-01fdb2b3241ff8740", ubuntu2404amd64 = "ami-0a521938209d49867", ubuntu2404arm64 = "ami-0ab5ec08b9d8128d1" }
    us-east-2                    = { linuxamd64 = "ami-0e7221e508c79cac1", linuxarm64 = "ami-0c91326fd51056ff6", windows = "ami-0ef62dc1b336ae4b1", ubuntu2404amd64 = "ami-0f724e05e15bea1bb", ubuntu2404arm64 = "ami-0670bda1bdbd8737d" }
    us-west-1                    = { linuxamd64 = "ami-0cc3df6e852b13335", linuxarm64 = "ami-0fa3e6d7f3c0bbc1e", windows = "ami-0ce0812423583acde", ubuntu2404amd64 = "ami-00a81b8c95dd01446", ubuntu2404arm64 = "ami-05474de569de8e90e" }
    us-west-2                    = { linuxamd64 = "ami-04a0a0390a4c8e472", linuxarm64 = "ami-03f8457d897befe23", windows = "ami-0026360f688a9d441", ubuntu2404amd64 = "ami-0330dd0324cac878d", ubuntu2404arm64 = "ami-0afae121d1d1b4ffa" }
    af-south-1                   = { linuxamd64 = "ami-00c8d3aa8c2f02194", linuxarm64 = "ami-0a686790dc8a6e55d", windows = "ami-0a0ec37f3dc21c713", ubuntu2404amd64 = "ami-00814664c1d150b87", ubuntu2404arm64 = "ami-0f621455f3c4f2b49" }
    ap-east-1                    = { linuxamd64 = "ami-08f20d0ab589c8b97", linuxarm64 = "ami-05e638e7721ed7338", windows = "ami-056e5e4f2cf56f6ab", ubuntu2404amd64 = "ami-08708d373cbc6cb62", ubuntu2404arm64 = "ami-05913236c01cbd9a6" }
    ap-south-1                   = { linuxamd64 = "ami-0d3bd51e5be76d1b2", linuxarm64 = "ami-0292c439248c1645b", windows = "ami-0e7648764ecf528ab", ubuntu2404amd64 = "ami-0f93ba033eae233b8", ubuntu2404arm64 = "ami-07fa3a1c864fd6e09" }
    ap-northeast-2               = { linuxamd64 = "ami-057076c04665ab845", linuxarm64 = "ami-0e6b8535ba110466a", windows = "ami-01239ef10b801a399", ubuntu2404amd64 = "ami-023abf0afaceecbcd", ubuntu2404arm64 = "ami-031c30a0419b2cb6a" }
    ap-northeast-1               = { linuxamd64 = "ami-0ecb3bc5078e6cb60", linuxarm64 = "ami-0e6e6b6e92eb42ad2", windows = "ami-02f27bc33e7f0cd06", ubuntu2404amd64 = "ami-0e0298231ebc0c06f", ubuntu2404arm64 = "ami-0c252115c4bc719d1" }
    ap-southeast-2               = { linuxamd64 = "ami-02d4d854d08d8d3b0", linuxarm64 = "ami-094de7be3cd740463", windows = "ami-0d41965ba71ea18ed", ubuntu2404amd64 = "ami-080816e36c5ef8730", ubuntu2404arm64 = "ami-0cb6993d7baadca54" }
    ap-southeast-1               = { linuxamd64 = "ami-0294ea2d77a2cd278", linuxarm64 = "ami-05d7602020297aeb5", windows = "ami-0fd9d72589be15466", ubuntu2404amd64 = "ami-0b9b8c3fa75d92319", ubuntu2404arm64 = "ami-09910ed6ebc8a7188" }
    ca-central-1                 = { linuxamd64 = "ami-0276c1926541d69dd", linuxarm64 = "ami-0c4818594078623d3", windows = "ami-08844dbd51e8a3dad", ubuntu2404amd64 = "ami-0c92991bc636f9003", ubuntu2404arm64 = "ami-04ac823e9cf1ce80b" }
    eu-central-1                 = { linuxamd64 = "ami-0400187263eb37ac1", linuxarm64 = "ami-0514890427e4a24fc", windows = "ami-00d7f8d3ed9ed59a2", ubuntu2404amd64 = "ami-01ebf3691fe0f92c6", ubuntu2404arm64 = "ami-0423efcd8405e5195" }
    eu-west-1                    = { linuxamd64 = "ami-0f4a011071bcbd1a5", linuxarm64 = "ami-0841464776eac5f1f", windows = "ami-097a12c0b1a73eda5", ubuntu2404amd64 = "ami-00de922e1e36aba1d", ubuntu2404arm64 = "ami-0b88f4d279965ce8f" }
    eu-west-2                    = { linuxamd64 = "ami-0c92fd0e5ca896ace", linuxarm64 = "ami-0e1ab9dc6871e2161", windows = "ami-0e4c8485ac3ffcc84", ubuntu2404amd64 = "ami-041c36bbd4b2e4240", ubuntu2404arm64 = "ami-02b025b877dbbbb16" }
    eu-south-1                   = { linuxamd64 = "ami-0722e3b7428f4b258", linuxarm64 = "ami-03fd5abd0d37992c1", windows = "ami-0069c22ad9b16fc18", ubuntu2404amd64 = "ami-02b6236d42f92b967", ubuntu2404arm64 = "ami-0e1cf70c888540ba7" }
    eu-west-3                    = { linuxamd64 = "ami-0110d5fb751c76ee5", linuxarm64 = "ami-0cdf66666bf2ef020", windows = "ami-0bc698b70554f9614", ubuntu2404amd64 = "ami-0ad71e62ac53d599b", ubuntu2404arm64 = "ami-0a96365f686fb7dae" }
    eu-north-1                   = { linuxamd64 = "ami-092d1c1c12fd4fe46", linuxarm64 = "ami-0cd89ba2dddb97d80", windows = "ami-0d5d49f4cd562b2d6", ubuntu2404amd64 = "ami-034cd6070c0967696", ubuntu2404arm64 = "ami-0d164c1a54b82632e" }
    sa-east-1                    = { linuxamd64 = "ami-0c24b88002d9c9852", linuxarm64 = "ami-0a0318e54fd38513b", windows = "ami-0149eb2afe396f426", ubuntu2404amd64 = "ami-08e16b65a48d8072a", ubuntu2404arm64 = "ami-0c5f63818f31ef696" }
    cloudformation_stack_version = "v7.4.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.0"
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
