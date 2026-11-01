# ---------------------------------------------------------------- security groups
# Least privilege chain: internet -> public ALB -> front -> internal ALB -> back -> RDS.
# SSH only from your IP to the bastion, and from the bastion to the private hosts.

resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion"
  description = "Bastion: SSH from the admin IP only"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${local.name}-bastion" }
}

resource "aws_security_group" "front" {
  name        = "${local.name}-front"
  description = "Front-end: app port from the public ALB, SSH from the bastion"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${local.name}-front" }
}

resource "aws_security_group" "back" {
  name        = "${local.name}-back"
  description = "Back-end: API port from the internal ALB, SSH from the bastion"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${local.name}-back" }
}

resource "aws_security_group" "db" {
  name        = "${local.name}-db"
  description = "RDS: MySQL from the back-end only"
  vpc_id      = module.vpc.vpc_id
  tags        = { Name = "${local.name}-db" }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH from admin IP"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.admin_cidr
}

resource "aws_vpc_security_group_ingress_rule" "front_app" {
  security_group_id            = aws_security_group.front.id
  description                  = "App port from public ALB"
  ip_protocol                  = "tcp"
  from_port                    = 3030
  to_port                      = 3030
  referenced_security_group_id = module.alb_public.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "back_app" {
  security_group_id            = aws_security_group.back.id
  description                  = "API port from internal ALB"
  ip_protocol                  = "tcp"
  from_port                    = 3000
  to_port                      = 3000
  referenced_security_group_id = module.alb_internal.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "ssh_from_bastion" {
  for_each = { front = aws_security_group.front.id, back = aws_security_group.back.id }

  security_group_id            = each.value
  description                  = "SSH from bastion (Ansible)"
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
  referenced_security_group_id = aws_security_group.bastion.id
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from back-end"
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  referenced_security_group_id = aws_security_group.back.id
}

# Instances need outbound internet (packages via NAT) and to reach each other.
resource "aws_vpc_security_group_egress_rule" "all" {
  for_each = {
    bastion = aws_security_group.bastion.id
    front   = aws_security_group.front.id
    back    = aws_security_group.back.id
  }

  security_group_id = each.value
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
