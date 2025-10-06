# Existing VPC Example

Use this if you already have a VPC set up and want to deploy agents into it. The example shows deploying into private subnets without public IPs, using your existing security groups.

You'll need a VPC with at least 2 subnets in different availability zones. Security groups should allow outbound HTTPS to the Buildkite API and AWS services (S3, SSM, ECR, CloudWatch). If you're using private subnets, make sure you have a NAT Gateway or VPC endpoints configured.

## Usage

```bash
terraform init
terraform apply \
  -var="buildkite_agent_token=YOUR_TOKEN" \
  -var="vpc_id=vpc-xxxxx" \
  -var='security_group_ids=["sg-xxxxx", "sg-yyyyy"]'
```

Agents need to reach `agent.buildkite.com:443`, plus AWS services like S3, SSM, and CloudWatch on 443. If you're pulling Docker images, they'll need access to Docker Hub or ECR too.

VPC endpoints can save you money on NAT Gateway data transfer if you're doing a lot of S3 or ECR traffic.
