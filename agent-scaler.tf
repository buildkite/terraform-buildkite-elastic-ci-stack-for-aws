#tfsec:ignore:aws-lambda-enable-tracing X-Ray tracing is optional and can be enabled by users if required for debugging
resource "aws_lambda_function" "scaler" {
  count = local.has_variable_size ? 1 : 0

  function_name = "${local.stack_name_full}-scaler"
  description   = "Scales ${aws_autoscaling_group.agent_auto_scale_group.name} based on Buildkite metrics"

  s3_bucket = local.agent_scaler_s3_bucket
  s3_key    = "buildkite-agent-scaler/v${var.buildkite_agent_scaler_version}/handler${var.lambda_architecture == "arm64" ? "-arm64" : ""}.zip"

  handler       = "bootstrap"
  runtime       = "provided.al2"
  architectures = [var.lambda_architecture]
  timeout       = 120
  memory_size   = 128

  role = local.use_custom_scaler_lambda_role ? var.scaler_lambda_role_arn : aws_iam_role.scaler_lambda_role[0].arn

  environment {
    variables = {
      # Required parameters
      BUILDKITE_AGENT_TOKEN_SSM_KEY = local.use_custom_token_path ? var.buildkite_agent_token_parameter_store_path : aws_ssm_parameter.buildkite_agent_token_parameter[0].name
      BUILDKITE_QUEUE               = var.buildkite_queue
      AGENTS_PER_INSTANCE           = tostring(var.agents_per_instance)
      ASG_NAME                      = aws_autoscaling_group.agent_auto_scale_group.name

      # Optional agent endpoint
      BUILDKITE_AGENT_ENDPOINT = var.agent_endpoint

      # Scaling configuration
      BUILDKITE_USER_AGENT_METADATA = "elastic-ci-stack-for-aws/${local.buildkite_ami_mapping.cloudformation_stack_version}/terraform"
      DISABLE_SCALE_IN              = var.disable_scale_in ? "true" : "false"
      SCALE_IN_COOLDOWN_PERIOD      = "${var.scale_in_cooldown_period}s"
      SCALE_OUT_COOLDOWN_PERIOD     = "${var.scale_out_cooldown_period}s"
      SCALE_OUT_FACTOR              = tostring(var.scale_out_factor)
      INSTANCE_BUFFER               = tostring(var.instance_buffer)
      INCLUDE_WAITING               = var.scale_out_for_waiting_jobs ? "true" : "false"

      # Lambda behavior
      # Convert EventBridge schedule period to Go duration format for LAMBDA_INTERVAL
      # EventBridge uses "1 minute" but Go expects "1m" or "60s"
      LAMBDA_INTERVAL = replace(replace(var.scaler_event_schedule_period, " minute", "m"), " minutes", "m")
      LAMBDA_TIMEOUT  = "110s" # Less than function timeout to allow graceful exit

      # Polling configuration
      MIN_POLL_INTERVAL = var.scaler_min_poll_interval

      # Elastic CI Mode (experimental)
      ELASTIC_CI_MODE = var.scaler_enable_elastic_ci_mode ? "true" : "false"

      # CloudWatch metrics (optional)
      CLOUDWATCH_METRICS = "false" # Can be made configurable if needed
    }
  }

  # Ensure the log group exists before the function
  depends_on = [
    aws_cloudwatch_log_group.scaler_lambda_logs[0],
    aws_iam_role_policy_attachment.scaler_lambda_policy[0]
  ]

  tags = local.common_tags
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key Using default encryption for CloudWatch Logs; CMK can be added by users if required
resource "aws_cloudwatch_log_group" "scaler_lambda_logs" {
  count = local.has_variable_size ? 1 : 0

  name              = "/aws/lambda/${local.stack_name_full}-scaler"
  retention_in_days = var.lambda_log_retention_days

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "scaler_schedule" {
  count               = local.has_variable_size ? 1 : 0
  name                = "${local.stack_name_full}-scaler-schedule"
  description         = "Triggers Buildkite agent scaler Lambda every ${var.scaler_event_schedule_period}"
  schedule_expression = "rate(${var.scaler_event_schedule_period})"

  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "scaler_lambda" {
  count = local.has_variable_size ? 1 : 0

  rule      = aws_cloudwatch_event_rule.scaler_schedule[0].name
  target_id = "BuildkiteAgentScalerLambda"
  arn       = aws_lambda_function.scaler[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count = local.has_variable_size ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scaler[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scaler_schedule[0].arn
}

resource "aws_iam_role" "scaler_lambda_role" {
  count = local.use_custom_scaler_lambda_role ? 0 : (local.has_variable_size ? 1 : 0)

  name                 = "${local.stack_name_full}-scaler-lambda-role"
  permissions_boundary = local.use_permissions_boundary ? var.instance_role_permissions_boundary_arn : null

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

#tfsec:ignore:aws-iam-no-policy-wildcards Lambda requires CloudWatch Logs CreateLogGroup permission with wildcard for dynamic log group creation
resource "aws_iam_role_policy" "scaler_lambda_policy" {
  count = local.use_custom_scaler_lambda_role ? 0 : (local.has_variable_size ? 1 : 0)

  name = "${local.stack_name_full}-scaler-lambda-policy"
  role = aws_iam_role.scaler_lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        # CloudWatch Logs
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "${aws_cloudwatch_log_group.scaler_lambda_logs[0].arn}:*"
        },
        # Auto Scaling - Core scaler permissions
        {
          Effect = "Allow"
          Action = [
            "autoscaling:DescribeAutoScalingGroups",
            "autoscaling:DescribeScalingActivities",
            "autoscaling:SetDesiredCapacity"
          ]
          Resource = "*"
        },
        # SSM Parameter Store - Token retrieval
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter"
          ]
          Resource = local.use_custom_token_path ? "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:parameter${var.buildkite_agent_token_parameter_store_path}" : aws_ssm_parameter.buildkite_agent_token_parameter[0].arn
        }
      ],
      # KMS for encrypted SSM parameter (if using customer-managed key)
      local.use_custom_token_kms ? [
        {
          Effect = "Allow"
          Action = [
            "kms:Decrypt"
          ]
          Resource = var.buildkite_agent_token_parameter_store_kms_key
        }
      ] : [],
      # Elastic CI Mode - Enhanced permissions for graceful scale-in
      # Split into separate conditionals to avoid type mismatch
      var.scaler_enable_elastic_ci_mode ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:DescribeInstances"
          ]
          Resource = "*"
        }
      ] : [],
      var.scaler_enable_elastic_ci_mode ? [
        {
          Effect = "Allow"
          Action = [
            "ssm:SendCommand",
            "ssm:GetCommandInvocation"
          ]
          Resource = [
            "arn:aws:ssm:${data.aws_region.current.id}::document/AWS-RunShellScript",
            "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"
          ]
        }
      ] : [],
      var.scaler_enable_elastic_ci_mode ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:TerminateInstances"
          ]
          Resource = "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"
          Condition = {
            StringEquals = {
              "ec2:ResourceTag/aws:autoscaling:groupName" = aws_autoscaling_group.agent_auto_scale_group.name
            }
          }
        }
      ] : []
    )
  })
}

resource "aws_iam_role_policy_attachment" "scaler_lambda_policy" {
  count = local.use_custom_scaler_lambda_role ? 0 : (local.has_variable_size ? 1 : 0)

  role       = aws_iam_role.scaler_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
