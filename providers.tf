terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.36"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~>0.70"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "awscc" {
  region = "eu-west-2"
}