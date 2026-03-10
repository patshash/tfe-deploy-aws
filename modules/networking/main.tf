data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  db_subnets      = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 8, i + 20)]
}

#------------------------------------------------------
# VPC
#------------------------------------------------------
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-vpc"
  })
}

#------------------------------------------------------
# Internet Gateway
#------------------------------------------------------
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-igw"
  })
}

#------------------------------------------------------
# Public Subnets
#------------------------------------------------------
resource "aws_subnet" "public" {
  for_each = { for i, az in local.azs : az => local.public_subnets[i] }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-public-${each.key}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

#------------------------------------------------------
# NAT Gateways (one per AZ for HA)
#------------------------------------------------------
resource "aws_eip" "nat" {
  for_each = aws_subnet.public

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-nat-eip-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

#------------------------------------------------------
# Private Subnets (TFE instances)
#------------------------------------------------------
resource "aws_subnet" "private" {
  for_each = { for i, az in local.azs : az => local.private_subnets[i] }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-private-${each.key}"
  })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-private-rt-${each.key}"
  })
}

resource "aws_route" "private_nat" {
  for_each = aws_nat_gateway.this

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = each.value.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

#------------------------------------------------------
# Database Subnets
#------------------------------------------------------
resource "aws_subnet" "database" {
  for_each = { for i, az in local.azs : az => local.db_subnets[i] }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-db-${each.key}"
  })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.friendly_name_prefix}-tfe-db"
  subnet_ids = [for s in aws_subnet.database : s.id]

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-db-subnet-group"
  })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.friendly_name_prefix}-tfe-redis"
  subnet_ids = [for s in aws_subnet.database : s.id]

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-redis-subnet-group"
  })
}

#------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------
resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-flow-logs"
  })
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flow-logs/${var.friendly_name_prefix}-tfe"
  retention_in_days = 30

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.friendly_name_prefix}-tfe-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.friendly_name_prefix}-tfe-flow-logs"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.flow_logs.arn}:*"
    }]
  })
}

#------------------------------------------------------
# Security Groups
#------------------------------------------------------

# ALB Security Group
resource "aws_security_group" "alb" {
  name_prefix = "${var.friendly_name_prefix}-tfe-alb-"
  description = "Security group for TFE ALB"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-alb-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from VPC and Direct Connect"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_tfe" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Allow traffic to TFE instances"
  referenced_security_group_id = aws_security_group.tfe.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

# TFE Instance Security Group
resource "aws_security_group" "tfe" {
  name_prefix = "${var.friendly_name_prefix}-tfe-instance-"
  description = "Security group for TFE EC2 instances"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-instance-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "tfe_https_from_alb" {
  security_group_id            = aws_security_group.tfe.id
  description                  = "Allow HTTPS from ALB"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "tfe_vault_cluster" {
  security_group_id            = aws_security_group.tfe.id
  description                  = "Allow Vault cluster traffic between TFE instances"
  referenced_security_group_id = aws_security_group.tfe.id
  from_port                    = 8201
  to_port                      = 8201
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "tfe_all_outbound" {
  security_group_id = aws_security_group.tfe.id
  description       = "Allow all outbound traffic (required for online mode)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Database Security Group
resource "aws_security_group" "database" {
  name_prefix = "${var.friendly_name_prefix}-tfe-db-"
  description = "Security group for TFE RDS PostgreSQL"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_tfe" {
  security_group_id            = aws_security_group.database.id
  description                  = "Allow PostgreSQL from TFE instances"
  referenced_security_group_id = aws_security_group.tfe.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# Redis Security Group
resource "aws_security_group" "redis" {
  name_prefix = "${var.friendly_name_prefix}-tfe-redis-"
  description = "Security group for TFE ElastiCache Redis"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_tfe" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Allow Redis from TFE instances"
  referenced_security_group_id = aws_security_group.tfe.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
