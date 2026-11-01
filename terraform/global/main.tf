# One-time, environment-independent resources (no workspaces). Kept out of the qa/prod
# stack so the email subscription survives every destroy and is confirmed only once.
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "tfstate-597564119372-us-east-1"
    key          = "global/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "epam-final-task"
      Environment = "global"
      Owner       = "amluis"
      ManagedBy   = "terraform"
    }
  }
}

variable "alert_email" {
  description = "Receives CloudWatch alarm notifications (must confirm the SNS email once)"
  type        = string
}

resource "aws_sns_topic" "alerts" {
  name = "epam-final-task-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

output "alerts_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
