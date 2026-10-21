terraform {
    backend "s3" {
        bucket = "aws-serverless-security-hardening-tfstate-jcxt211026"
        key    = "aws-serverless-security-hardening/terraform.tfstate"
        region = "ap-southeast-1"
        use_lockfile = true
        encrypt = true
    }

    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 6.0"
        }
        archive = {
            source = "hashicorp/archive"
            version = "~> 2.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}