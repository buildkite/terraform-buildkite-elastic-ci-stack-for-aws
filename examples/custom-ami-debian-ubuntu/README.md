# Debian or Ubuntu custom AMI example

Uses `custom_user_data` to run the stack on a Debian- or Ubuntu-based AMI rather than a Buildkite Elastic CI Stack AMI.

The user-data template installs the Buildkite agent, reads its token from SSM Parameter Store, configures agent-driven idle scale-in, and starts the agent service. It intentionally does not reproduce Docker, plugins, logging, or other software included in Buildkite's AMIs.

## Production AMIs

This example bootstraps an unmodified distribution AMI so it can be run without first building an image. A production AMI would normally include:

- The Buildkite agent package, systemd unit, user, and directories
- AWS CLI v2 and `curl`, which this template uses to read the token and terminate the instance
- AWS Systems Manager Agent when using Elastic CI mode or graceful shutdown
- Any required plugins, Docker configuration, logging, monitoring, and security software

When these dependencies are baked into the AMI, remove the package repository, package installation, and AWS CLI installation steps from `user-data.sh.tftpl`. The remaining user data supplies deployment-specific configuration, retrieves the agent token, configures idle scale-in, and starts the agent. Build and patch the AMI through the normal image pipeline rather than installing software on every instance launch.

## Assumptions

The AMI:

- Is Debian or Ubuntu with `apt`, cloud-init, and systemd.
- Uses the device configured by `root_volume_name` (`/dev/sda1` by default).
- When using the template as written, can reach the Ubuntu or Debian package repositories, `apt.buildkite.com`, `keys.openpgp.org`, and `awscli.amazonaws.com`.
- Can reach AWS APIs and the Buildkite Agent API.
- Is compatible with the configured EC2 instance types.

This example uses the default scaler mode. To enable `scaler_enable_elastic_ci_mode` or `buildkite_agent_enable_graceful_shutdown`, install and run AWS Systems Manager Agent on the AMI.

## Usage

```bash
terraform init
terraform plan \
  -var="image_id=ami-0123456789abcdef0" \
  -var="buildkite_agent_token=YOUR_CLUSTER_TOKEN"
terraform apply \
  -var="image_id=ami-0123456789abcdef0" \
  -var="buildkite_agent_token=YOUR_CLUSTER_TOKEN"
```

Change `stack_name` and `buildkite_agent_token_parameter_store_path` when deploying more than one copy of this example in an AWS account and region.

The token is marked sensitive in Terraform output but is still stored in Terraform state. Protect access to the state file.
