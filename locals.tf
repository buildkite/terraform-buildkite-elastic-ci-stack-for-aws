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
    us-east-1                    = { linuxamd64 = "ami-0532f5bfab774f4be", linuxarm64 = "ami-01843b7f83a5690f0", windows = "ami-0128c807ecfa805fa" }
    us-east-2                    = { linuxamd64 = "ami-05f0d6e00ad7f8b46", linuxarm64 = "ami-0315c6e8e1d34f15a", windows = "ami-0d32109042d736f8c" }
    us-west-1                    = { linuxamd64 = "ami-0c84d880b0bc34b1e", linuxarm64 = "ami-0f176fb02bb2cab67", windows = "ami-0575d2bfa578c2c34" }
    us-west-2                    = { linuxamd64 = "ami-00dca08669f26b68d", linuxarm64 = "ami-0b1dea1625ad11813", windows = "ami-04bcc917d9943214d" }
    af-south-1                   = { linuxamd64 = "ami-02602b38daa66595b", linuxarm64 = "ami-002312433bb97b86b", windows = "ami-0b34dc05b88eed14c" }
    ap-east-1                    = { linuxamd64 = "ami-016d4c8d432457239", linuxarm64 = "ami-0d5343a84cb4d30fb", windows = "ami-01b8a6c9710aed44c" }
    ap-south-1                   = { linuxamd64 = "ami-083b433de563ba849", linuxarm64 = "ami-0788c039632ae4605", windows = "ami-0bcd51b67a0f513de" }
    ap-northeast-2               = { linuxamd64 = "ami-009a5b1a9ff481eed", linuxarm64 = "ami-081bf579039f796f3", windows = "ami-0d960501e4077eed7" }
    ap-northeast-1               = { linuxamd64 = "ami-06bf16739f5b4bb79", linuxarm64 = "ami-080386f8cad72218d", windows = "ami-08c452a5a23e68c6c" }
    ap-southeast-2               = { linuxamd64 = "ami-09c2c13dd8a1bcd29", linuxarm64 = "ami-060e20647e424b785", windows = "ami-0a749533c649227e2" }
    ap-southeast-1               = { linuxamd64 = "ami-050fdc411e4be58b5", linuxarm64 = "ami-01fbde129faa7c13d", windows = "ami-07c31afcdaabb6d8b" }
    ca-central-1                 = { linuxamd64 = "ami-03113ab567d7c8858", linuxarm64 = "ami-0085567b045a64490", windows = "ami-038898fa3a2188999" }
    eu-central-1                 = { linuxamd64 = "ami-0085f5386208eba03", linuxarm64 = "ami-06efc5751092153b9", windows = "ami-0cbf6752fe19ed07a" }
    eu-west-1                    = { linuxamd64 = "ami-03ba8acbc3ec342cb", linuxarm64 = "ami-05608c2c7e5d5ab85", windows = "ami-03c50e81973a17e25" }
    eu-west-2                    = { linuxamd64 = "ami-0854b1612fc8f1c3f", linuxarm64 = "ami-02bd6a20726e98ec9", windows = "ami-0fda796bea953d9fc" }
    eu-south-1                   = { linuxamd64 = "ami-009890110cec3320f", linuxarm64 = "ami-093c661da8a6c44c4", windows = "ami-029349f9f2668e53a" }
    eu-west-3                    = { linuxamd64 = "ami-0b45690b1b5ec1fec", linuxarm64 = "ami-0b30be3b641213257", windows = "ami-0be62579a8dca9c80" }
    eu-north-1                   = { linuxamd64 = "ami-0915c109eb62f60ac", linuxarm64 = "ami-0d6f90211b0e99cb8", windows = "ami-03de9dbe81fde697f" }
    me-south-1                   = { linuxamd64 = "ami-0092eee64aa4327af", linuxarm64 = "ami-04fb5388f24a1c095", windows = "ami-0e17ab0c57bbac505" }
    sa-east-1                    = { linuxamd64 = "ami-01a3a26b8c6114fa1", linuxarm64 = "ami-0069bd23da639cd3f", windows = "ami-08ac97708584088e9" }
    cloudformation_stack_version = "v6.58.5"
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
