variable "stack_name" {
  description = "Unique name used as a prefix for resources created by the example."
  type        = string
  default     = "buildkite-custom-ami"
}

variable "image_id" {
  description = "AMI ID for a Debian or Ubuntu image with cloud-init, systemd, and an apt package manager."
  type        = string
}

variable "buildkite_agent_token" {
  description = "Buildkite cluster agent token."
  type        = string
  sensitive   = true
}

variable "buildkite_agent_token_parameter_store_path" {
  description = "SSM Parameter Store path at which to store the Buildkite agent token."
  type        = string
  default     = "/buildkite/examples/custom-ami/agent-token"
}

variable "buildkite_queue" {
  description = "Buildkite cluster queue on which the agents run."
  type        = string
  default     = "custom-ami"
}

variable "agent_endpoint" {
  description = "Buildkite Agent API endpoint."
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

variable "agents_per_instance" {
  description = "Number of Buildkite agents to run on each instance."
  type        = number
  default     = 1
}

variable "scale_in_idle_period" {
  description = "Number of seconds agents remain idle before stopping the instance."
  type        = number
  default     = 600
}

variable "instance_types" {
  description = "Comma-separated EC2 instance types compatible with the selected AMI."
  type        = string
  default     = "t3.large"
}

variable "root_volume_name" {
  description = "Root device name used by the selected AMI."
  type        = string
  default     = "/dev/sda1"
}
