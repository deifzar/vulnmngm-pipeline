# Security Group

resource "aws_security_group" "scg" {
  name        = var.name
  description = var.description
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    name = var.name
  })
}

# Egress rules

resource "aws_vpc_security_group_egress_rule" "egress_rule" {
  for_each                     = var.egress_rules
  security_group_id            = aws_security_group.scg.id
  description                  = each.value.description
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  referenced_security_group_id = each.value.referenced_security_group_id

  depends_on = [aws_security_group.scg]
}

# Ingress rules

resource "aws_vpc_security_group_ingress_rule" "ingress_rule" {
  for_each                     = var.ingress_rules
  security_group_id            = aws_security_group.scg.id
  description                  = each.value.description
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  ip_protocol                  = each.value.ip_protocol
  cidr_ipv4                    = each.value.cidr_ipv4
  cidr_ipv6                    = each.value.cidr_ipv6
  referenced_security_group_id = each.value.referenced_security_group_id

  depends_on = [aws_security_group.scg]
}

