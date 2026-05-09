terraform {
  backend "s3" {
    # Shared remote state (best-practice naming: project + purpose + region).
    bucket = "postech-terraform-state-us-east-1"
    key    = "postech/prod/terraform.tfstate"
    region = "us-east-1"
    # State lock table for concurrent apply protection.
    dynamodb_table = "postech-terraform-locks"
    encrypt        = true
  }
}

