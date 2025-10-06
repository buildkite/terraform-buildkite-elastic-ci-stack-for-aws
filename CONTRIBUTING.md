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

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [terraform-docs](https://terraform-docs.io/) for documentation
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

Releases are managed by maintainers. The process includes:

1. Version bump in relevant files
2. Update CHANGELOG.md
3. Create GitHub release with notes
4. Tag the release (semantic versioning)

## Questions?

- Open a [GitHub Discussion](https://github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws/discussions)
- Join the [Buildkite Community Slack](https://buildkite.com/slack)
- Check the [Buildkite Documentation](https://buildkite.com/docs)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
