FROM hashicorp/terraform:1.13

RUN apk add --no-cache \
    bash \
    curl \
    git \
    yq \
    jq

WORKDIR /workdir
ENTRYPOINT ["/bin/bash"]
