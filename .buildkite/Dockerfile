FROM hashicorp/terraform:1.9.8

# Install terraform-docs
RUN apk add --no-cache curl && \
    TFDOCS_VERSION="0.20.0" && \
    curl -sSLo terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TFDOCS_VERSION}/terraform-docs-v${TFDOCS_VERSION}-linux-amd64.tar.gz" && \
    tar -xzf terraform-docs.tar.gz && \
    mv terraform-docs /usr/local/bin/ && \
    rm terraform-docs.tar.gz && \
    chmod +x /usr/local/bin/terraform-docs

# Install git to git diff docs
RUN apk add --no-cache git

WORKDIR /workspace
