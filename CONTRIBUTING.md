# Contributing to Buildkite Elastic CI Stack for AWS (Terraform)

Thank you for considering contributing to this project! We welcome contributions from the community.

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## How to Contribute

### Reporting Bugs

- Use the [GitHub issue tracker](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/issues)
- Check if the bug has already been reported
- Include:
  - Terraform version
  - AWS provider version
  - Minimal reproduction steps
  - Expected vs actual behavior
  - Relevant log output (redact sensitive information)

### Suggesting Features

- Open an issue with the `enhancement` label
- Describe the use case and benefits
- Consider if it fits the project's scope
- Be open to discussion and feedback

### Pull Requests

Fork the repo and create your branch from `main`. Make your changes following the existing code style, and add documentation or examples if you're introducing new features.

Before submitting, test everything:
```bash
terraform init
terraform validate
terraform plan
```

Format your code and update docs:
```bash
terraform fmt -recursive
terraform-docs markdown table . --output-file README.md --output-mode inject
```

Add comments for anything complex. Write clear commit messages and reference issues when relevant (like "Fixes #123").

When you open the PR, explain what changed and why. Link any related issues and tag maintainers for review.

## Development Setup

### Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.11
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [terraform-docs](https://terraform-docs.io/) 0.24.0 for documentation (matching CI)
- [pre-commit](https://pre-commit.com/) (optional but recommended)

### Local Testing

1. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/terraform-buildkite-elastic-ci-stack-for-aws.git
   cd terraform-buildkite-elastic-ci-stack-for-aws
   ```

2. Create a test configuration:
   ```bash
   cd examples/basic
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. Test the module:
   ```bash
   terraform init
   terraform plan
   terraform apply  # Only if you want to actually create resources
   terraform destroy  # Clean up when done
   ```

### Code Style

Stick to 2 spaces for indentation and follow the [Terraform Style Guide](https://www.terraform.io/docs/language/syntax/style.html). Run `terraform fmt -recursive` before you commit. Try to keep lines under 120 characters, and add comments when you're doing something non-obvious.

### Documentation

Every variable needs a description. If it's complex, add examples to help people understand what goes there. Before opening a PR, regenerate the README:

```bash
terraform-docs markdown table . --output-file README.md
```

CI checks that the root README's generated Terraform reference is up to date without modifying it. After changing root module inputs, outputs, or requirements, regenerate the reference and commit the README with your changes.

To run the same check locally from the repository root:

```bash
.buildkite/scripts/docs-check.sh
```

## Project Structure

```
.
├── *.tf                    # Main Terraform configuration files
├── scripts/                # User data scripts
├── examples/               # Usage examples
│   ├── basic/             # Minimal configuration
│   ├── spot-instances/    # Cost-optimized setup
│   ├── existing-vpc/      # Deploy into existing VPC
│   └── scheduled-scaling/ # Time-based scaling
├── .github/               # GitHub templates and workflows
└── README.md              # Generated documentation
```

## Release Process

Maintainers cut releases from `main`. A release is a `vX.Y.Z` Git tag on a `main` commit whose CI passed.

> [!IMPORTANT]
> The Terraform Registry publishes a new module version as soon as a `vX.Y.Z` tag is pushed. Publishing a GitHub release creates its tag, so it publishes the version too. Published versions can't be changed, so every change in a release must be on `main` before you publish the GitHub release.

### 1. Choose the version

Compare `main` with the previous release (`https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/compare/vA.B.C...main`) and choose the release type:

| Release type | Use when | Examples |
| --- | --- | --- |
| Major (`vX.0.0`) | Upgrading can break an existing configuration or deployment, or needs manual steps | Removing or renaming an input variable or output; changing a default incompatibly; a new Buildkite Agent major version; a new Elastic CI Stack for AWS major version |
| Minor (`vX.Y.0`) | New behavior that existing configurations don't need to change for | A new input variable whose default keeps existing behavior; a new output; AMIs from a new Elastic CI Stack for AWS minor version |
| Patch (`vX.Y.Z`) | Backwards-compatible fixes only | Bug fixes; AMIs from a new Elastic CI Stack for AWS patch version; documentation |

If the changes span more than one type, use the largest. If you're unsure, use the larger type.

Tags always have a leading `v` (for example `v1.2.0`). This process covers stable releases only.

### 2. Merge prerequisites

Merge these before the release:

- **AMIs.** To ship AMIs from a newer [Elastic CI Stack for AWS](https://github.com/buildkite/elastic-ci-stack-for-aws/releases) release, merge the Renovate pull request that updates `cloudformation_stack_version` and `buildkite_ami_mapping` in `locals.tf`.
- **Major releases only.** Land these with the breaking change:
  - Add `docs/upgrading-to-vX.md` and link it from `README.md`.
  - Set the module example in `README.md` to `version = "~> X.0"`.

There is no version to bump for minor and patch releases. `README.md` and the examples pin `~> X.0`, so they pick up new minor and patch versions without changes.

### 3. Publish the GitHub release

Draft the release on the `main` commit you're releasing:

```bash
gh release create vX.Y.Z --draft --target COMMIT_SHA --title vX.Y.Z --generate-notes
```

Review the draft notes:

- Keep the upgrade callout from the previous release at the top. For a major release, write a new one that links `docs/upgrading-to-vX.md`.
- Move pull requests that only change CI, linting or other repository tooling under an `### Internal` heading.

Then publish the draft. Publishing creates the `vX.Y.Z` tag, and the Terraform Registry publishes the version.

### 4. Check the release

- `vX.Y.Z` appears on the [Terraform Registry](https://registry.terraform.io/modules/buildkite/elastic-ci-stack-for-aws/buildkite) within a few minutes. If it doesn't, select **Resync Module** under **Manage Module** on the registry page.
- Fetch the published tag with `git fetch origin tag vX.Y.Z`, then check that `git rev-parse 'vX.Y.Z^{commit}'` matches the commit you released.
- **Major releases only:** the examples use the registry module, so they can't pin `~> X.0` until it's published. Merge the Renovate pull request that updates them, or update `version` in `examples/*/main.tf` yourself.

If anything is wrong after the release is published, don't move or delete the tag. Fix it on `main` and release a new patch version.

## Questions?

- Open a [GitHub Issue](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/issues)
- Check the [Buildkite Documentation](https://buildkite.com/docs)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
