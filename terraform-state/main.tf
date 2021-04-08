#
# Provider Configuration
#

provider "aws" {
  region = var.region
  version = "~> 3.27.0"
}

terraform {
  backend "s3" {
  }
}

# Using these data sources allows the configuration to be
# generic for any region.
data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

# data bucket where tf state and possibly other stuff is stored
resource "aws_s3_bucket" "tf-state" {
  bucket = "login-dot-gov-eks.${data.aws_caller_identity.current.account_id}-${var.region}"
  acl    = "private"
  policy = ""
  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# make sure bucket isn't public in any way
resource "aws_s3_bucket_public_access_block" "tf-state" {
  bucket = aws_s3_bucket.tf-state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# set up tfstate lock table
resource "aws_dynamodb_table" "tf-lock-table" {
  name           = "eks_terraform_locks"
  read_capacity  = 2
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
   enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "aws_caller_identity" "current" {
} 
