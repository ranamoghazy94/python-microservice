terraform {
  backend "s3" {
    bucket = "terraform-aws12"
    key    = "aws-terraform-test.tfstate"
    region = "eu-west-1"
  }
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
provider "aws" {
  region = "eu-west-1"
}