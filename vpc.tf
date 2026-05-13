#tfsec:ignore:aws-ec2-require-vpc-flow-logs-for-all-vpcs VPC Flow Logs are optional and can be enabled by users if required
resource "aws_vpc" "vpc" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = local.common_tags
}

resource "aws_internet_gateway" "gateway" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags = merge(local.common_tags, {
    Name = local.stack_name_full
  })
}

resource "aws_subnet" "subnets" {
  for_each          = local.create_vpc ? { for idx, az in local.availability_zones : az => idx } : {}
  availability_zone = each.key
  cidr_block        = "10.0.${each.value}.0/24"
  vpc_id            = aws_vpc.vpc[0].id
  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-subnet-${each.key}"
  })
}

resource "aws_route_table" "routes" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.vpc[0].id
  tags   = local.common_tags
}

resource "aws_route" "route_default" {
  count                  = local.create_vpc ? 1 : 0
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway[0].id
  route_table_id         = aws_route_table.routes[0].id
}

resource "aws_route_table_association" "subnet_routes" {
  for_each = aws_subnet.subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.routes[0].id
}

resource "aws_security_group" "security_group" {
  count       = local.create_security_group ? 1 : 0
  name        = "${local.stack_name_full}-agent-sg"
  description = "Enable access to agents"
  vpc_id      = local.create_vpc ? aws_vpc.vpc[0].id : var.vpc_id
  tags        = local.common_tags

  # Allow all outbound traffic (required for agents to connect to Buildkite, download artifacts, etc.)
  #tfsec:ignore:aws-ec2-no-public-egress-sgr Buildkite agents require internet access to connect to Buildkite API and download artifacts
  #tfsec:ignore:aws-ec2-add-description-to-security-group-rule Description provided in comment above
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "security_group_ssh_ingress" {
  count             = local.enable_ssh_ingress ? 1 : 0
  security_group_id = aws_security_group.security_group[0].id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "0.0.0.0/0"
}

# VPC Endpoints for SSM connectivity
resource "aws_vpc_endpoint" "ssm_endpoint" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint_subnet_association" "ssm" {
  for_each = aws_subnet.subnets
  vpc_endpoint_id = aws_vpc_endpoint.ssm_endpoint[0].id
  subnet_id       = aws_subnet.subnets[each.key].id
}

resource "aws_vpc_endpoint" "ssmmessages_endpoint" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint_subnet_association" "ssmmessages" {
  for_each = aws_subnet.subnets
  vpc_endpoint_id = aws_vpc_endpoint.ssmmessages_endpoint[0].id
  subnet_id       = aws_subnet.subnets[each.key].id
}

resource "aws_vpc_endpoint" "ec2messages_endpoint" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ec2messages-endpoint"
  })
}

resource "aws_vpc_endpoint_subnet_association" "ec2messages" {
  for_each = aws_subnet.subnets
  vpc_endpoint_id = aws_vpc_endpoint.ec2messages_endpoint[0].id
  subnet_id       = aws_subnet.subnets[each.key].id
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  count       = local.create_vpc ? 1 : 0
  name        = "${local.stack_name_full}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.vpc[0].id

  #tfsec:ignore:aws-ec2-add-description-to-security-group-rule HTTPS ingress from VPC for endpoint access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc[0].cidr_block]
  }

  #tfsec:ignore:aws-ec2-no-public-egress-sgr VPC endpoints require egress for AWS service communication
  #tfsec:ignore:aws-ec2-add-description-to-security-group-rule Egress required for VPC endpoint responses
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-vpc-endpoints-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}
