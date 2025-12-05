data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
    Component = "network"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-igw"
    Component = "network"
  })
}

resource "aws_subnet" "public" {
  for_each = { for idx, cidr in var.public_subnet_cidrs : tostring(idx) => cidr }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = local.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = merge(var.common_tags, {
    Name  = "${var.project_name}-${var.environment}-public-${each.key}"
    Component = "network"
  })
}

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : tostring(idx) => cidr }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key)]

  tags = merge(var.common_tags, {
    Name  = "${var.project_name}-${var.environment}-private-${each.key}"
    Component = "network"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-nat-eip"
    Component = "network"
  })
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["0"].id

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-nat"
    Component = "network"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-public-rt"
    Component = "network"
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

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-private-rt"
    Component = "network"
  })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Lambda security group"
  vpc_id      = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name      = "${var.project_name}-${var.environment}-lambda-sg"
    Component = "lambda"
  })
}
