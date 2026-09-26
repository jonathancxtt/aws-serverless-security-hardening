variable "project_name" {
    type = string
    description = "The name of the project"
    default = "aws-serverless-security-hardening"
}

variable "aws_region" {
    type = string
    description = "The region of the project"
    default = "ap-southeast-1"
}

variable "my_ip" {
  description = "Your public IP address for API Gateway restriction during testing"
  type = string
}