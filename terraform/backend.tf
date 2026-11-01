# Bucket created by hand (versioned, encrypted, public access blocked).
# Each workspace gets its own state: env:/qa/final-task/terraform.tfstate, env:/prod/...
terraform {
  backend "s3" {
    bucket       = "tfstate-597564119372-us-east-1"
    key          = "final-task/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
