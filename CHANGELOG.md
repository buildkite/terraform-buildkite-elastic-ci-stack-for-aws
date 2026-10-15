# Changelog

All notable changes to this project are documented in this file. For releases before v1.2.0, see [GitHub Releases](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/releases).

## [v1.2.0](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/tree/v1.2.0) (2026-10-15)

[Full Changelog](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/compare/v1.1.0...v1.2.0)

### Added

- Seed git mirrors from S3 at instance boot with `git_mirror_seed_bucket` [#174](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/174) (@dmikalova)
- Restrict container access to instance metadata with `imds_hop_limit` [#169](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/169) (@petetomasik)
- Use a VPC created in the same Terraform run with `create_vpc` [#168](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/168) (@petetomasik)

### Changed

- Update Elastic CI Stack for AWS AMIs to v7.6.0, which ships Buildkite Agent v4.5.0 [#173](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/173) (@renovate[bot])

### Fixed

- Remove the instance termination lifecycle hook that delayed every termination by an hour when graceful shutdown was enabled [#170](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/170) (@petetomasik)

### Internal

- Update tflint-ruleset-aws to v0.49.0 [#154](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/154) (@renovate[bot])
- Bump examples to 1.1.0 [#172](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/pull/172) (@scadu)
