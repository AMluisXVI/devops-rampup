# ---------------------------------------------------------------- load balancers
# Two ALBs: public one for the front-end, internal one for the back-end (required:
# back-end traffic through a load balancer). Free tier covers 750 ALB-hours/month;
# two ALBs fit because the stack is destroyed after every session.

module "alb_public" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.5"

  name                       = "${local.name}-pub"
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.public_subnets
  enable_deletion_protection = false

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    vpc = {
      ip_protocol = "-1"
      cidr_ipv4   = local.cfg.vpc_cidr
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward  = { target_group_key = "front" }
    }
  }

  target_groups = {
    front = {
      name_prefix = "front-"
      protocol    = "HTTP"
      port        = 3030
      target_type = "instance"
      target_id   = module.front.id
      health_check = {
        path    = "/"
        matcher = "200"
      }
    }
  }
}

module "alb_internal" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.5"

  name                       = "${local.name}-int"
  internal                   = true
  vpc_id                     = module.vpc.vpc_id
  subnets                    = module.vpc.private_subnets
  enable_deletion_protection = false

  security_group_ingress_rules = {
    from_front = {
      from_port                    = 80
      to_port                      = 80
      ip_protocol                  = "tcp"
      referenced_security_group_id = aws_security_group.front.id
    }
  }
  security_group_egress_rules = {
    vpc = {
      ip_protocol = "-1"
      cidr_ipv4   = local.cfg.vpc_cidr
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward  = { target_group_key = "back" }
    }
  }

  target_groups = {
    back = {
      name_prefix = "back-"
      protocol    = "HTTP"
      port        = 3000
      target_type = "instance"
      target_id   = module.back.id
      health_check = {
        # "/" answers without touching the DB; /movies hangs on DB errors (app bug: res.staus)
        path    = "/"
        matcher = "200"
      }
    }
  }
}
