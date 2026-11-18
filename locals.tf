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

  # The AMI only seeds git mirrors on Linux, and only when mirrors are enabled.
  has_git_mirror_seed_bucket = !local.is_windows && var.buildkite_agent_enable_git_mirrors && var.git_mirror_seed_bucket != ""
  git_mirror_seeds_prefix    = "git-mirror-seeds"

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

  # managed_policy_arns entries stay keyed by ARN so existing attachments keep
  # their state addresses. managed_policies entries are keyed by the caller's
  # static names, so their ARNs can be unknown until apply.
  instance_managed_policies = merge(
    { for arn in toset(var.managed_policy_arns) : arn => arn },
    var.managed_policies,
  )

  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0feb7749aea82182e", linuxarm64 = "ami-08924ce5737fec9dc", windows = "ami-0402973078388576d", ubuntu2404amd64 = "ami-0f69559b174a9f066", ubuntu2404arm64 = "ami-0161c7f7bd4a5e944", windows2025 = "ami-0a1824bd72980c9f4" }
    us-east-2                    = { linuxamd64 = "ami-07a9858252a616093", linuxarm64 = "ami-0caf8155f5742bbdb", windows = "ami-07013f48d55144894", ubuntu2404amd64 = "ami-014c75b8adf4b1192", ubuntu2404arm64 = "ami-016957e0180495f6c", windows2025 = "ami-00328a7f8e47e5569" }
    us-west-1                    = { linuxamd64 = "ami-038bf85edeb99c048", linuxarm64 = "ami-09b901287db9eef04", windows = "ami-00eb3a3e3e3c70914", ubuntu2404amd64 = "ami-02e7684691ddc1930", ubuntu2404arm64 = "ami-0b6c63df744ee844e", windows2025 = "ami-0f78bd76d3018984d" }
    us-west-2                    = { linuxamd64 = "ami-0584f9a2348f51516", linuxarm64 = "ami-0cecc25d31eff21b3", windows = "ami-058795ca655f1eff1", ubuntu2404amd64 = "ami-017483a60eb22e01f", ubuntu2404arm64 = "ami-0959f370a591f6805", windows2025 = "ami-08b5bc3aa76f3d217" }
    af-south-1                   = { linuxamd64 = "ami-052ef50377c0f2acd", linuxarm64 = "ami-00968aba4aa292b9e", windows = "ami-065e193815e7248ad", ubuntu2404amd64 = "ami-0c651a172ecf1573e", ubuntu2404arm64 = "ami-041f2f1a297b0d187", windows2025 = "ami-0c94e7476f68a3656" }
    ap-east-1                    = { linuxamd64 = "ami-0d40971932aa7d141", linuxarm64 = "ami-0ef0acc5b6ad8feb1", windows = "ami-01078c361fda85da2", ubuntu2404amd64 = "ami-0f79d99ebf37092fc", ubuntu2404arm64 = "ami-0fa7382ddbc60481c", windows2025 = "ami-0727c9114ea6aa236" }
    ap-south-1                   = { linuxamd64 = "ami-0d9798c8e8130f761", linuxarm64 = "ami-05c39ed3808f0e5cc", windows = "ami-09d6cbd202711b704", ubuntu2404amd64 = "ami-0edd44de00dbd7388", ubuntu2404arm64 = "ami-059a36755c78c2799", windows2025 = "ami-0ec70712b3e140c1e" }
    ap-northeast-2               = { linuxamd64 = "ami-05e87c60279b8a055", linuxarm64 = "ami-00926d6afbebe69a8", windows = "ami-08af9989e21bae4b2", ubuntu2404amd64 = "ami-0acdd021ca96bea3a", ubuntu2404arm64 = "ami-07b1a1c7efa942dde", windows2025 = "ami-0e04cdd6ca6c88b31" }
    ap-northeast-1               = { linuxamd64 = "ami-0065b0b941ef0ce0d", linuxarm64 = "ami-0af16e08e81896937", windows = "ami-0a0220cd157c95155", ubuntu2404amd64 = "ami-04a80fbbe6e353fb9", ubuntu2404arm64 = "ami-0f2edb77ae3ea5be1", windows2025 = "ami-0729337d48c0d5a63" }
    ap-southeast-2               = { linuxamd64 = "ami-03dc4dabe475a6a05", linuxarm64 = "ami-0c1cb24ef27939c61", windows = "ami-0df5b3050a904b8f5", ubuntu2404amd64 = "ami-007938861bb30d7f8", ubuntu2404arm64 = "ami-0ef532f0b068d9bf3", windows2025 = "ami-09943a7bcf0e771de" }
    ap-southeast-1               = { linuxamd64 = "ami-04332a8595084037f", linuxarm64 = "ami-00c41f42fcddb8467", windows = "ami-062113599cffbca93", ubuntu2404amd64 = "ami-018449d956f79d8fc", ubuntu2404arm64 = "ami-0b0054a101a2cdcdf", windows2025 = "ami-047a49949deef91c8" }
    ca-central-1                 = { linuxamd64 = "ami-083f8997359bc58aa", linuxarm64 = "ami-00a00c7f0cc36f350", windows = "ami-01f2d9ca8e63fa153", ubuntu2404amd64 = "ami-0c1942a9ba58c4814", ubuntu2404arm64 = "ami-02ef2fd66a328de57", windows2025 = "ami-0187eed3ee2e1455d" }
    eu-central-1                 = { linuxamd64 = "ami-0f221658c68567042", linuxarm64 = "ami-0e5337385ba1f7649", windows = "ami-0c88341b6e29ac66b", ubuntu2404amd64 = "ami-072057d68a8cf0567", ubuntu2404arm64 = "ami-066de6c57e2f3d8f3", windows2025 = "ami-0e99a97da158af175" }
    eu-west-1                    = { linuxamd64 = "ami-000fac5b0674b848a", linuxarm64 = "ami-0e38973dbba6f99f9", windows = "ami-05ff9768daa9a9931", ubuntu2404amd64 = "ami-08e1d6054b6f0c6aa", ubuntu2404arm64 = "ami-0f0a7c7cb637f4e80", windows2025 = "ami-06bacd6476f6c48d0" }
    eu-west-2                    = { linuxamd64 = "ami-0654fae70c3f0ae5c", linuxarm64 = "ami-0f5ade6aa862f670d", windows = "ami-003c6b81da4c06eb0", ubuntu2404amd64 = "ami-07af05a87a704e843", ubuntu2404arm64 = "ami-0eabb91751703b096", windows2025 = "ami-0c2d3844366108bb0" }
    eu-south-1                   = { linuxamd64 = "ami-08aba445a6634ac15", linuxarm64 = "ami-00cd10bfdae7a2ef7", windows = "ami-0019b1c10c174c824", ubuntu2404amd64 = "ami-02f326f811ad75d8e", ubuntu2404arm64 = "ami-0919759d36bd42ae7", windows2025 = "ami-05aa40fe67073e6cc" }
    eu-west-3                    = { linuxamd64 = "ami-04ef794480bc15487", linuxarm64 = "ami-076c0386e6c39ffc6", windows = "ami-08a28938f98f5f5a4", ubuntu2404amd64 = "ami-01f0c15bbc64ca946", ubuntu2404arm64 = "ami-07ad6d54304f97054", windows2025 = "ami-080c909ec7b745ac4" }
    eu-north-1                   = { linuxamd64 = "ami-0829ae89c36eee93c", linuxarm64 = "ami-00da68f5b0679b495", windows = "ami-027d802aa6d506168", ubuntu2404amd64 = "ami-0e9b94de9b2b04cf2", ubuntu2404arm64 = "ami-01acaebc9a8798ff9", windows2025 = "ami-08129d861055e3592" }
    sa-east-1                    = { linuxamd64 = "ami-0fc6de138b51b6477", linuxarm64 = "ami-0f4f8ff2279fa72fc", windows = "ami-0778a7593a6b9aa0b", ubuntu2404amd64 = "ami-087aadbea691793a9", ubuntu2404arm64 = "ami-081f525babc304057", windows2025 = "ami-0126047a813de2f97" }
    cloudformation_stack_version = "v7.12.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.1"
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
  ami_architecture = local.is_windows ? (var.windows_server_version == "2025" ? "windows2025" : "windows") : (
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
  token_path_is_arn        = startswith(var.buildkite_agent_token_parameter_store_path, "arn:")
  use_custom_token_kms     = var.buildkite_agent_token_parameter_store_kms_key != ""
  token_kms_key_is_arn     = startswith(var.buildkite_agent_token_parameter_store_kms_key, "arn:")
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
  # A parameter shared from another account is referenced by its full ARN.
  agent_token_parameter_arn = local.token_path_is_arn ? var.buildkite_agent_token_parameter_store_path : (
    local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"
  )

  # Computed agent token KMS key ARN (for IAM policies). A key in another account must be given as an ARN.
  agent_token_kms_key_arn = local.token_kms_key_is_arn ? var.buildkite_agent_token_parameter_store_kms_key : "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${var.buildkite_agent_token_parameter_store_kms_key}"

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
