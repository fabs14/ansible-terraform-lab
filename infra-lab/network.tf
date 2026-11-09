data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "lab" {
  cidr_block           = "10.84.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.deployment_name}-vpc" }
}

resource "aws_subnet" "lab" {
  for_each = {
    public  = "10.84.1.0/24"
    private = "10.84.2.0/24"
  }

  vpc_id            = aws_vpc.lab.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.available.names[0]
  tags              = { Name = "${var.deployment_name}-${each.key}" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
  tags   = { Name = "${var.deployment_name}-igw" }
}

resource "aws_route_table" "lab" {
  for_each = aws_subnet.lab

  vpc_id = aws_vpc.lab.id
  tags   = { Name = "${var.deployment_name}-${each.key}" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.lab["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.lab.id
}

resource "aws_route_table_association" "lab" {
  for_each = aws_subnet.lab

  subnet_id      = each.value.id
  route_table_id = aws_route_table.lab[each.key].id
}
