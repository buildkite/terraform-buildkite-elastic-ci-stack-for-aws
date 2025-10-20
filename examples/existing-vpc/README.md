# Existing VPC Example

Demonstrates deploying Buildkite agents into an existing VPC infrastructure. This configuration deploys into private subnets without public IP addresses, using existing security groups.

## Configuration

This example provides:

- Integration with existing VPC infrastructure
- Private subnet deployment without public IP addresses
- Custom security group configuration
- NAT Gateway and VPC endpoint compatibility

## Prerequisites

- Existing VPC with at least 2 subnets in different availability zones
- Security groups configured for outbound HTTPS access to:
  - Buildkite API (`agent.buildkite.com:443`)
  - AWS services (S3, SSM, ECR, CloudWatch on port 443)
  - Docker registries (Docker Hub, ECR) for container builds
- NAT Gateway or VPC endpoints configured for private subnet internet access
- Buildkite agent registration token

## Usage

```bash
terraform init

terraform plan \
  -var="buildkite_agent_token=YOUR_TOKEN" \
  -var="vpc_id=vpc-xxxxx" \
  -var='security_group_ids=["sg-xxxxx", "sg-yyyyy"]'

terraform apply \
  -var="buildkite_agent_token=YOUR_TOKEN" \
  -var="vpc_id=vpc-xxxxx" \
  -var='security_group_ids=["sg-xxxxx", "sg-yyyyy"]'
```

## Network Requirements

Outbound HTTPS (port 443) access to external services is required. VPC endpoints are recommended for cost optimization with high S3/ECR traffic volumes.
