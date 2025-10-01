resource "aws_kms_key" "pipeline_signing_kms_key" {
  count                    = local.create_signing_key ? 1 : 0
  description              = "KMS key for signing Buildkite pipelines"
  customer_master_key_spec = var.pipeline_signing_config.kms_key_spec
  key_usage                = "SIGN_VERIFY"
  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-PipelineSigningKey"
  })
}