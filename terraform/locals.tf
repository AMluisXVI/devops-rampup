locals {
  env  = terraform.workspace
  name = "${var.project}-${local.env}"

  # Per-environment sizing keyed by workspace: running in "default" or an unknown
  # workspace fails here instead of creating stray infrastructure.
  settings = {
    qa = {
      vpc_cidr = "10.0.0.0/16"
    }
    prod = {
      vpc_cidr = "10.1.0.0/16"
    }
  }
  cfg = local.settings[local.env]

  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}
