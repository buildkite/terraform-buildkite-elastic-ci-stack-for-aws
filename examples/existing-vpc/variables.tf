variable "buildkite_agent_token" {
  description = "Buildkite agent registration token"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "ID of existing VPC"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to instances"
  type        = list(string)
}
