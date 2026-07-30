data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" {
  state = "available"

  # Only use standard regional Availability Zones. Opted-in edge zones may
  # not support regional services such as the SSM VPC endpoints.
  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}