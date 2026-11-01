provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = local.env
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}
