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
  tags = {
    Name = local.stack_name_full
  }
}



resource "aws_subnet" "subnet0" {
  count             = local.create_vpc ? 1 : 0
  availability_zone = local.use_custom_azs ? element(split(",", var.availability_zones), 0) : element(data.aws_availability_zones.available.names, 0)
  cidr_block        = "10.0.1.0/24"
  vpc_id            = aws_vpc.vpc[0].id
  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-subnet0"
  })
}

resource "aws_subnet" "subnet1" {
  count             = local.create_vpc ? 1 : 0
  availability_zone = local.use_custom_azs ? element(split(",", var.availability_zones), 1) : element(data.aws_availability_zones.available.names, 1)
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.vpc[0].id
  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-subnet1"
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

resource "aws_route_table_association" "subnet0_routes" {
  count          = local.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.subnet0[0].id
  route_table_id = aws_route_table.routes[0].id
}

resource "aws_route_table_association" "subnet1_routes" {
  count          = local.create_vpc ? 1 : 0
  subnet_id      = aws_subnet.subnet1[0].id
  route_table_id = aws_route_table.routes[0].id
}

resource "aws_security_group" "security_group" {
  count       = local.create_security_group ? 1 : 0
  name        = "${local.stack_name_full}-agent-sg"
  description = "Enable access to agents"
  vpc_id      = local.create_vpc ? aws_vpc.vpc[0].id : var.vpc_id
  tags        = local.common_tags

  # Allow all outbound traffic (required for agents to connect to Buildkite, download artifacts, etc.)
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
resource "aws_vpc_endpoint" "ssm" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet0[0].id, aws_subnet.subnet1[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet0[0].id, aws_subnet.subnet1[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = local.create_vpc ? 1 : 0
  vpc_id              = aws_vpc.vpc[0].id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet0[0].id, aws_subnet.subnet1[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoint_sg[0].id]
  private_dns_enabled = true

  tags = merge(local.common_tags, {
    Name = "${local.stack_name_full}-ec2messages-endpoint"
  })
}

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoint_sg" {
  count       = local.create_vpc ? 1 : 0
  name        = "${local.stack_name_full}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.vpc[0].id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc[0].cidr_block]
  }

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