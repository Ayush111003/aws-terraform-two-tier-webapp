terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "group2-dev-bucket-terraform"
    key    = "webservers/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "group2-dev-bucket-terraform"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
