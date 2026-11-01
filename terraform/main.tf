# ---------------------------------------------------------------- network
# Public module for VPC, subnets, IGW and route tables. NAT Gateway is disabled
# (not free tier); private/database routes point to our NAT instance instead.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.7"

  name = local.name
  cidr = local.cfg.vpc_cidr
  azs  = local.azs

  public_subnets   = [for i in range(2) : cidrsubnet(local.cfg.vpc_cidr, 8, i)]      # ALB, NAT
  private_subnets  = [for i in range(2) : cidrsubnet(local.cfg.vpc_cidr, 8, 10 + i)] # front, back, internal ALB
  database_subnets = [for i in range(2) : cidrsubnet(local.cfg.vpc_cidr, 8, 20 + i)] # RDS (subnet group needs 2 AZ)

  enable_nat_gateway                 = false
  single_nat_gateway                 = true # only shapes route tables: one private + one database table, both via the NAT instance
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  enable_dns_hostnames = true
  enable_dns_support   = true
}

# Management subnet for the bastion (separate layer, as in the reference diagram);
# routed to the internet through the public route table.
resource "aws_subnet" "management" {
  vpc_id                  = module.vpc.vpc_id
  cidr_block              = cidrsubnet(local.cfg.vpc_cidr, 8, 30)
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-management" }
}

resource "aws_route_table_association" "management" {
  subnet_id      = aws_subnet.management.id
  route_table_id = module.vpc.public_route_table_ids[0]
}

module "nat" {
  source = "./modules/nat-instance"

  name            = local.name
  vpc_id          = module.vpc.vpc_id
  vpc_cidr        = local.cfg.vpc_cidr
  subnet_id       = module.vpc.public_subnets[0]
  route_table_ids = concat(module.vpc.private_route_table_ids, module.vpc.database_route_table_ids)
}
