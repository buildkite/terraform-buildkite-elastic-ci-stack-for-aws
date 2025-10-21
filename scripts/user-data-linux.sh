Content-Type: multipart/mixed; boundary="==BOUNDARY=="
MIME-Version: 1.0
--==BOUNDARY==
Content-Type: text/cloud-config; charset="us-ascii"
#cloud-config
cloud_final_modules:
  - [scripts-user, always]
--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash -v
BUILDKITE_ENABLE_INSTANCE_STORAGE="${enable_instance_storage}" \
BUILDKITE_MOUNT_TMPFS_AT_TMP="${mount_tmpfs_at_tmp}" \
  /usr/local/bin/bk-mount-instance-storage.sh
--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash -v
DOCKER_USERNS_REMAP=${enable_docker_userns_remap} \
DOCKER_EXPERIMENTAL=${enable_docker_experimental} \
DOCKER_NETWORKING_PROTOCOL=${docker_networking_protocol} \
DOCKER_IPV4_ADDRESS_POOL_1=${docker_ipv4_address_pool_1} \
DOCKER_IPV4_ADDRESS_POOL_2=${docker_ipv4_address_pool_2} \
DOCKER_IPV6_ADDRESS_POOL=${docker_ipv6_address_pool} \
DOCKER_FIXED_CIDR_V4="${docker_fixed_cidr_v4}" \
DOCKER_FIXED_CIDR_V6="${docker_fixed_cidr_v6}" \
BUILDKITE_ENABLE_INSTANCE_STORAGE="${enable_instance_storage}" \
  /usr/local/bin/bk-configure-docker.sh
--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash -v
# Ensure SSM Agent is installed and running
yum update -y
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl status amazon-ssm-agent
--==BOUNDARY==
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash -v
BUILDKITE_STACK_NAME="${stack_name}" \
BUILDKITE_STACK_VERSION="${stack_version}" \
BUILDKITE_SCALE_IN_IDLE_PERIOD="${scale_in_idle_period}" \
BUILDKITE_SECRETS_BUCKET="${secrets_bucket}" \
BUILDKITE_SECRETS_BUCKET_REGION="${secrets_bucket_region}" \
BUILDKITE_ARTIFACTS_BUCKET="${artifacts_bucket}" \
BUILDKITE_S3_DEFAULT_REGION="${artifacts_bucket_region}" \
BUILDKITE_S3_ACL="${artifacts_s3_acl}" \
BUILDKITE_AGENT_TOKEN_PATH="${agent_token_path}" \
BUILDKITE_AGENTS_PER_INSTANCE="${agents_per_instance}" \
BUILDKITE_AGENT_ENDPOINT="${agent_endpoint}" \
BUILDKITE_AGENT_TAGS="${agent_tags}" \
BUILDKITE_AGENT_TIMESTAMP_LINES="${agent_timestamp_lines}" \
BUILDKITE_AGENT_EXPERIMENTS="${agent_experiments}" \
BUILDKITE_AGENT_TRACING_BACKEND="${agent_tracing_backend}" \
BUILDKITE_AGENT_RELEASE="${agent_release}" \
BUILDKITE_AGENT_CANCEL_GRACE_PERIOD="${agent_cancel_grace_period}" \
BUILDKITE_AGENT_SIGNAL_GRACE_PERIOD_SECONDS="${agent_signal_grace_period}" \
BUILDKITE_AGENT_SIGNING_KMS_KEY="${agent_signing_kms_key}" \
BUILDKITE_AGENT_SIGNING_KEY_PATH="${agent_signing_jwks_path}" \
BUILDKITE_AGENT_SIGNING_KEY_ID="${agent_signing_jwks_key_id}" \
BUILDKITE_AGENT_VERIFICATION_KEY_PATH="${agent_verification_jwks_path}" \
BUILDKITE_AGENT_JOB_VERIFICATION_NO_SIGNATURE_BEHAVIOR="${agent_signing_failure_behavior}" \
BUILDKITE_QUEUE="${queue}" \
BUILDKITE_AGENT_ENABLE_GIT_MIRRORS="${agent_enable_git_mirrors}" \
BUILDKITE_ELASTIC_BOOTSTRAP_SCRIPT="${bootstrap_script_url}" \
BUILDKITE_ENV_FILE_URL=${agent_env_file_url} \
BUILDKITE_ENABLE_INSTANCE_STORAGE="${enable_instance_storage}" \
BUILDKITE_AUTHORIZED_USERS_URL="${authorized_users_url}" \
BUILDKITE_ECR_POLICY="${ecr_access_policy}" \
BUILDKITE_TERMINATE_INSTANCE_AFTER_JOB="${terminate_instance_after_job}" \
BUILDKITE_AGENT_DISCONNECT_AFTER_UPTIME="${agent_disconnect_after_uptime}" \
BUILDKITE_TERMINATE_INSTANCE_ON_DISK_FULL="${terminate_instance_on_disk_full}" \
BUILDKITE_PURGE_BUILDS_ON_DISK_FULL="${purge_builds_on_disk_full}" \
BUILDKITE_ADDITIONAL_SUDO_PERMISSIONS="${additional_sudo_permissions}" \
AWS_DEFAULT_REGION="${aws_region}" \
SECRETS_PLUGIN_ENABLED="${enable_secrets_plugin}" \
ECR_PLUGIN_ENABLED="${enable_ecr_plugin}" \
ECR_CREDENTIAL_HELPER_ENABLED="${enable_ecr_credential_helper}" \
DOCKER_LOGIN_PLUGIN_ENABLED="${enable_docker_login_plugin}" \
DOCKER_EXPERIMENTAL="${enable_docker_experimental}" \
DOCKER_USERNS_REMAP=${enable_docker_userns_remap} \
AWS_REGION="${aws_region}" \
ENABLE_RESOURCE_LIMITS="${enable_resource_limits}" \
RESOURCE_LIMITS_MEMORY_HIGH="${resource_limits_memory_high}" \
RESOURCE_LIMITS_MEMORY_MAX="${resource_limits_memory_max}" \
RESOURCE_LIMITS_MEMORY_SWAP_MAX="${resource_limits_memory_swap_max}" \
RESOURCE_LIMITS_CPU_WEIGHT="${resource_limits_cpu_weight}" \
RESOURCE_LIMITS_CPU_QUOTA="${resource_limits_cpu_quota}" \
RESOURCE_LIMITS_IO_WEIGHT="${resource_limits_io_weight}" \
ENABLE_EC2_LOG_RETENTION_POLICY="${enable_ec2_log_retention_policy}" \
EC2_LOG_RETENTION_DAYS="${ec2_log_retention_days}" \
  /usr/local/bin/bk-install-elastic-stack.sh
--==BOUNDARY==--
