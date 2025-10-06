# Main Terraform configuration
# Resources are organized into separate files:
# - dependencies.tf: Data sources (AWS account, region, partition)
# - provider.tf: Terraform and AWS provider configuration
# - random.tf: Random ID for unique resource naming
# - locals.tf: Local computed values
# - variables.tf: Input variables with validation
# - vpc.tf: VPC, subnets, security groups, VPC endpoints
# - autoscaling.tf: Launch template, ASG, scheduled actions
# - iam.tf: IAM roles, policies, instance profiles (including Lambda roles)
# - lifecycle-management.tf: Lambda functions for AZ rebalancing and graceful shutdown
# - agent-scaler.tf: Lambda-based agent scaler with EventBridge scheduling
# - s3.tf: S3 buckets for secrets and managed logging
# - kms.tf: KMS keys for pipeline signing
# - ssm.tf: SSM parameters for agent token
# - output.tf: Stack outputs