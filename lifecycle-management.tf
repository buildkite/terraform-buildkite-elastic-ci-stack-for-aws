# Disables AZ Rebalancing on the agent ASG to prevent mid-job termination
#tfsec:ignore:aws-lambda-enable-tracing X-Ray tracing is optional and can be enabled by users if required for debugging
resource "aws_lambda_function" "az_rebalancing_suspender" {
  function_name = "${local.stack_name_full}-az-rebalancing-suspender"
  description   = "Disables AZ Rebalancing on the agent ASG."
  role          = local.use_custom_asg_process_suspender_role ? var.asg_process_suspender_role_arn : aws_iam_role.asg_process_suspender[0].arn
  handler       = "index.handler"
  runtime       = "python3.13"
  architectures = [var.lambda_architecture]
  timeout       = 30

  filename         = data.archive_file.az_rebalancing_suspender.output_path
  source_code_hash = data.archive_file.az_rebalancing_suspender.output_base64sha256

  tags = local.common_tags
}

data "archive_file" "az_rebalancing_suspender" {
  type        = "zip"
  output_path = "${path.module}/.terraform/lambda/az-rebalancing-suspender.zip"

  source {
    content  = <<-PYTHON
      import boto3
      import json

      def handler(event, context):
        print(f"Received event: {json.dumps(event)}")

        try:
          # For Terraform invocations, we only care about Create/Update (not Delete)
          request_type = event.get('RequestType', 'Create')

          if request_type == 'Delete':
            print("Delete request - skipping AZ rebalancing suspension")
            return {'statusCode': 200, 'body': 'Success'}

          # Suspend AZ Rebalancing
          client = boto3.client('autoscaling')
          props = event.get('ResourceProperties', {})
          asg_name = props.get('AutoScalingGroupName')

          if not asg_name:
            raise ValueError("AutoScalingGroupName is required in ResourceProperties")

          print(f"Suspending AZ Rebalancing for ASG: {asg_name}")
          response = client.suspend_processes(
            AutoScalingGroupName=asg_name,
            ScalingProcesses=['AZRebalance']
          )

          print(f"Successfully suspended AZ Rebalancing: {response}")
          return {'statusCode': 200, 'body': 'Success'}

        except Exception as err:
          print(f'ERROR: {err}')
          raise
    PYTHON
    filename = "index.py"
  }
}

# Lambda invocation to suspend AZ rebalancing
resource "aws_lambda_invocation" "suspend_az_rebalance" {
  function_name = aws_lambda_function.az_rebalancing_suspender.function_name

  input = jsonencode({
    RequestType = "Create"
    ResourceProperties = {
      AutoScalingGroupName = aws_autoscaling_group.agent_auto_scale_group.name
    }
  })

  lifecycle {
    replace_triggered_by = [
      aws_autoscaling_group.agent_auto_scale_group
    ]
  }
}

# Stops all Buildkite agents gracefully during ASG updates/replacements
resource "aws_lambda_function" "stop_buildkite_agents" {
  count = local.enable_graceful_shutdown ? 1 : 0

  function_name = "${local.stack_name_full}-stop-buildkite-agents"
  description   = "Gracefully stops all Buildkite agents in a given Auto Scaling group."
  role          = local.use_custom_stop_buildkite_agents_role ? var.stop_buildkite_agents_role_arn : aws_iam_role.stop_buildkite_agents[0].arn
  handler       = "index.handler"
  runtime       = "python3.12"
  architectures = [var.lambda_architecture]
  timeout       = 60

  filename         = data.archive_file.stop_buildkite_agents[0].output_path
  source_code_hash = data.archive_file.stop_buildkite_agents[0].output_base64sha256

  tags = local.common_tags
}

data "archive_file" "stop_buildkite_agents" {
  count = local.enable_graceful_shutdown ? 1 : 0

  type        = "zip"
  output_path = "${path.module}/.terraform/lambda/stop-buildkite-agents.zip"

  source {
    content  = <<-PYTHON
      import boto3
      import logging
      import json

      logger = logging.getLogger()
      logger.setLevel(logging.INFO)

      autoscaling_client = boto3.client("autoscaling")
      ssm_client = boto3.client("ssm")

      def handler(event, context):
          logger.info(f"Received event: {json.dumps(event)}")

          try:
              # For Terraform invocations, we trigger on "Update" events (ASG replacement)
              request_type = event.get("RequestType", "Create")

              if request_type == "Update":
                  # Use OldResourceProperties if available, otherwise use ResourceProperties
                  props = event.get("OldResourceProperties", event.get("ResourceProperties", {}))
                  autoscaling_group_name = props.get("AutoScalingGroupName")

                  if not autoscaling_group_name:
                      raise ValueError("AutoScalingGroupName is required")

                  # Scale ASG down to zero, to allow Buildkite agents to terminate
                  force_instance_termination(autoscaling_group_name)

                  # Stop all Buildkite agents in the old ASG
                  stop_bk_agents(autoscaling_group_name)

                  return {'statusCode': 200, 'body': 'Success'}
              else:
                  # For Create and Delete events, just return success
                  logger.info(f"Skipping for {request_type} event")
                  return {'statusCode': 200, 'body': 'Success'}

          except Exception as e:
              logger.error(f"Error: {str(e)}")
              raise

      def force_instance_termination(autoscaling_group_name):
          """Forces all EC2 instances to terminate in the specified Auto Scaling group by setting the desired capacity to zero."""
          logger.info(f"Setting the desired capacity of {autoscaling_group_name} to zero")
          autoscaling_client.update_auto_scaling_group(
              AutoScalingGroupName=autoscaling_group_name,
              MinSize=0,
              DesiredCapacity=0
          )

      def stop_bk_agents(autoscaling_group_name):
          """Gracefully terminates Buildkite agents running in the given Auto Scaling Group."""
          stack_name = autoscaling_group_name.split("-asg")[0]

          logger.info(f"Stopping BK agents in {stack_name}")
          response = ssm_client.send_command(
              Targets=[
                  {
                      "Key": "tag:aws:autoscaling:groupName",
                      "Values": [autoscaling_group_name]
                  }
              ],
              DocumentName="AWS-RunShellScript",
              Comment=f"Stopping BK agents in {stack_name}",
              Parameters={
                  "commands": ["sudo kill -s SIGTERM $(/bin/pidof buildkite-agent)"]
              }
          )
          logger.info(f"SSM command response: {response}")
    PYTHON
    filename = "index.py"
  }
}

# Lambda invocation on ASG replacement
# Note: Terraform doesn't have a direct equivalent to CloudFormation Custom Resources
# that trigger on "Update" events. This is handled during terraform apply when the
# ASG is replaced, using lifecycle hooks and the lambda invocation.
resource "aws_lambda_invocation" "stop_buildkite_agents_on_replacement" {
  count = local.enable_graceful_shutdown ? 1 : 0

  function_name = aws_lambda_function.stop_buildkite_agents[0].function_name

  input = jsonencode({
    RequestType = "Update"
    OldResourceProperties = {
      AutoScalingGroupName = aws_autoscaling_group.agent_auto_scale_group.name
    }
  })

  # This will trigger when the ASG is replaced
  lifecycle {
    replace_triggered_by = [
      aws_autoscaling_group.agent_auto_scale_group
    ]
  }
}


# Gives agents time to finish current jobs before termination
resource "aws_autoscaling_lifecycle_hook" "instance_terminating" {
  count = local.enable_graceful_shutdown ? 1 : 0

  name                   = "${local.stack_name_full}-terminating-hook"
  autoscaling_group_name = aws_autoscaling_group.agent_auto_scale_group.name
  default_result         = "CONTINUE"
  heartbeat_timeout      = 3600 # 1 hour for agents to finish jobs
  lifecycle_transition   = "autoscaling:EC2_INSTANCE_TERMINATING"

  notification_metadata = jsonencode({
    stack_name = local.stack_name_full
    queue      = var.buildkite_queue
  })
}
