# =============================================================================
# IAM RESOURCES
# =============================================================================

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${local.stack_name_full}-InstanceProfile"
  path = "/"
  role = aws_iam_role.iam_role.name
}

resource "aws_iam_role" "iam_role" {
  name                 = local.use_custom_role_name ? var.security_config.instance_role_name : "${local.stack_name_full}-Role"
  permissions_boundary = local.use_permissions_boundary ? var.security_config.instance_role_permissions_boundary_arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach ECR managed policy if configured
resource "aws_iam_role_policy_attachment" "instance_ecr_policy" {
  count      = local.enable_ecr ? 1 : 0
  role       = aws_iam_role.iam_role.name
  policy_arn = local.ecr_policy_arns[var.docker_config.ecr_access_policy]
}

# Attach custom managed policies if configured
resource "aws_iam_role_policy_attachment" "instance_managed_policies" {
  for_each   = local.use_managed_policies ? toset(var.security_config.managed_policy_arns) : []
  role       = aws_iam_role.iam_role.name
  policy_arn = each.value
}

# Inline policy for Buildkite agent permissions
resource "aws_iam_role_policy" "buildkite_agent_policy" {
  name = "BuildkiteAgentPolicy"
  role = aws_iam_role.iam_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Ssm"
        Effect = "Allow"
        Action = [
          "ssm:DescribeInstanceProperties",
          "ssm:ListAssociations",
          "ssm:PutInventory",
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      },
      {
        Sid    = "SsmParameterAccess"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/*",
          local.agent_token_parameter_arn
        ]
      },
      {
        Sid    = "AutoScalingAccess"
        Effect = "Allow"
        Action = [
          "autoscaling:SetInstanceHealth"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3SecretsAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket"
        ]
        Resource = [
          local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].arn : "arn:aws:s3:::${var.s3_config.secrets_bucket}",
          "${local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].arn : "arn:aws:s3:::${var.s3_config.secrets_bucket}"}/*"
        ]
      },
      {
        Sid    = "CloudwatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutRetentionPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for AZ Rebalancing Suspender Lambda
resource "aws_iam_role" "asg_process_suspender" {
  name_prefix = "${local.stack_name_full}-az-suspend-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "asg_process_suspender_basic" {
  role       = aws_iam_role.asg_process_suspender.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "asg_process_suspender" {
  name = "suspend-asg-processes"
  role = aws_iam_role.asg_process_suspender.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "autoscaling:SuspendProcesses"
      Resource = "*"
    }]
  })
}

# IAM Role for Graceful Shutdown Lambda
resource "aws_iam_role" "stop_buildkite_agents" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name_prefix          = "${local.stack_name_full}-stop-bk-"
  permissions_boundary = local.use_permissions_boundary ? var.security_config.instance_role_permissions_boundary_arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "stop_buildkite_agents_basic" {
  count = local.enable_graceful_shutdown ? 1 : 0

  role       = aws_iam_role.stop_buildkite_agents[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "stop_buildkite_agents_describe_asg" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name = "describe-asgs"
  role = aws_iam_role.stop_buildkite_agents[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "autoscaling:DescribeAutoScalingGroups"
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy" "stop_buildkite_agents_modify_asg" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name = "modify-asgs"
  role = aws_iam_role.stop_buildkite_agents[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "autoscaling:UpdateAutoScalingGroup"
      Resource = "arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${local.stack_name_full}-AgentAutoScaleGroup-*"
    }]
  })
}

resource "aws_iam_role_policy" "stop_buildkite_agents_ssm_document" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name = "run-stop-buildkite-document"
  role = aws_iam_role.stop_buildkite_agents[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:SendCommand"
      Resource = "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.id}::document/AWS-RunShellScript"
    }]
  })
}

resource "aws_iam_role_policy" "stop_buildkite_agents_ssm_instances" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name = "stop-buildkite-instances"
  role = aws_iam_role.stop_buildkite_agents[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ssm:SendCommand"
      Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"
      Condition = {
        StringEquals = {
          "aws:resourceTag/aws:cloudformation:logical-id" = "AgentAutoScaleGroup"
        }
      }
    }]
  })
}
