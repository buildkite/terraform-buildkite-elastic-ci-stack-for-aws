# Basic Example

Simple setup with sensible defaults. Creates a new VPC with public subnets and auto-scales from 0 to 5 t3.large instances based on your build queue. Secrets and ECR plugins are enabled out of the box.

## Usage

```bash
terraform init
terraform plan -var="buildkite_agent_token=YOUR_TOKEN"
terraform apply -var="buildkite_agent_token=YOUR_TOKEN"
```

You'll need AWS credentials configured and a Buildkite agent token.

The module outputs the ASG name and instance role ARN in case you need to attach additional permissions later.
