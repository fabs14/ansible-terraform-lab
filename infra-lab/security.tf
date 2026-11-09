locals {
  public_servers = toset(["frontend", "backend"])
}

resource "aws_security_group" "lab" {
  for_each = local.servers

  name        = "${var.deployment_name}-${each.key}"
  description = "Attendance lab access for ${each.key}"
  vpc_id      = aws_vpc.lab.id
  tags        = { Name = "${var.deployment_name}-${each.key}" }
}

resource "aws_vpc_security_group_ingress_rule" "operator_ssh" {
  for_each = local.public_servers

  security_group_id = aws_security_group.lab[each.key].id
  cidr_ipv4         = var.operator_ipv4_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id = aws_security_group.lab["frontend"].id
  cidr_ipv4         = var.operator_ipv4_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "api" {
  security_group_id            = aws_security_group.lab["backend"].id
  referenced_security_group_id = aws_security_group.lab["frontend"].id
  from_port                    = 5000
  to_port                      = 5000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "database" {
  for_each = {
    ssh      = 22
    postgres = 5432
  }

  security_group_id            = aws_security_group.lab["database"].id
  referenced_security_group_id = aws_security_group.lab["backend"].id
  from_port                    = each.value
  to_port                      = each.value
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "public_servers" {
  for_each = local.public_servers

  security_group_id = aws_security_group.lab[each.key].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
