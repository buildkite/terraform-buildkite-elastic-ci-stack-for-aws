# =============================================================================
# IAM RESOURCES
# =============================================================================

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "${local.stack_name_full}-InstanceProfile"
  path = "/"
  role = local.use_custom_iam_role ? local.custom_role_name : aws_iam_role.iam_role[0].name
}

resource "aws_iam_role" "iam_role" {
  count = local.use_custom_iam_role ? 0 : 1

  name                 = local.use_custom_role_name ? var.instance_role_name : "${local.stack_name_full}-Role"
  permissions_boundary = local.use_permissions_boundary ? var.instance_role_permissions_boundary_arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "autoscaling.amazonaws.com",
            "ec2.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = local.common_tags
}

# Attach ECR managed policy if configured
resource "aws_iam_role_policy_attachment" "instance_ecr_policy" {
  count      = local.use_custom_iam_role ? 0 : (local.enable_ecr ? 1 : 0)
  role       = aws_iam_role.iam_role[0].name
  policy_arn = local.ecr_policy_arns[var.ecr_access_policy]
}

# Attach custom managed policies if configured
resource "aws_iam_role_policy_attachment" "instance_managed_policies" {
  for_each   = local.use_custom_iam_role ? toset([]) : (local.use_managed_policies ? toset(var.managed_policy_arns) : toset([]))
  role       = aws_iam_role.iam_role[0].name
  policy_arn = each.value
}

# Inline policy for Buildkite agent permissions
resource "aws_iam_role_policy" "buildkite_agent_policy" {
  count = local.use_custom_iam_role ? 0 : 1

  name = "BuildkiteAgentPolicy"
  role = aws_iam_role.iam_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
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
            "autoscaling:DescribeAutoScalingInstances",
            "autoscaling:SetInstanceHealth",
            "autoscaling:TerminateInstanceInAutoScalingGroup"
          ]
          Resource = "*"
        },
        {
          Sid    = "CloudWatchMetrics"
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
        },
        {
          Sid    = "StackResourceAccess"
          Effect = "Allow"
          Action = [
            "cloudformation:DescribeStackResource"
          ]
          Resource = "*"
        },
        {
          Sid    = "Ec2TagsAccess"
          Effect = "Allow"
          Action = [
            "ec2:DescribeTags"
          ]
          Resource = "*"
        }
      ],
      local.has_secrets_bucket ? [
        {
          Sid    = "S3SecretsAccess"
          Effect = "Allow"
          Action = [
            "s3:Get*",
            "s3:List*"
          ]
          Resource = [
            local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].arn : "arn:aws:s3:::${var.secrets_bucket}",
            "${local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].arn : "arn:aws:s3:::${var.secrets_bucket}"}/*"
          ]
        }
      ] : [],
      local.use_artifacts_bucket ? [
        {
          Sid    = "S3ArtifactsAccess"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectAcl",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl",
            "s3:ListBucket",
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:PutObjectVersionAcl"
          ]
          Resource = [
            "arn:aws:s3:::${var.artifacts_bucket}",
            "arn:aws:s3:::${var.artifacts_bucket}/*"
          ]
        }
      ] : [],
      [
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
      ],
      local.has_signing_key ? [
        {
          Sid    = "PipelineSigningKMSKeyAccess"
          Effect = "Allow"
          Action = concat(
            ["kms:Verify", "kms:GetPublicKey"],
            local.signing_key_full_access ? ["kms:Sign"] : []
          )
          Resource = local.signing_key_arn
        }
      ] : [],
      local.use_custom_token_kms ? [
        {
          Sid      = "DecryptAgentToken"
          Effect   = "Allow"
          Action   = "kms:Decrypt"
          Resource = "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${var.buildkite_agent_token_parameter_store_kms_key}"
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy" "ecr_pullthrough_policy" {
  count = local.use_custom_iam_role ? 0 : (local.enable_ecr_pullthrough ? 1 : 0)
  name  = "ECRPullThrough"
  role  = aws_iam_role.iam_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:BatchImportUpstreamImage",
          "ecr:GetImageCopyStatus",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for AZ Rebalancing Suspender Lambda
resource "aws_iam_role" "asg_process_suspender" {
  name = "${local.stack_name_full}-AsgProcessSuspenderRole"

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

#tfsec:ignore:aws-iam-no-policy-wildcards autoscaling:SuspendProcesses requires wildcard as ASG ARN is not known at policy creation time
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
  permissions_boundary = local.use_permissions_boundary ? var.instance_role_permissions_boundary_arn : null

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
      Resource = aws_autoscaling_group.agent_auto_scale_group.arn
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
          "aws:ResourceTag/aws:autoscaling:groupName" = aws_autoscaling_group.agent_auto_scale_group.name
        }
      }
    }]
  })
}
