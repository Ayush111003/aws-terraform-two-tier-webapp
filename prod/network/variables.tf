variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "Group2"
}

variable "environment" {
  type    = string
  default = "Prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.250.0.0/16"
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.250.1.0/24",
    "10.250.2.0/24",
    "10.250.3.0/24"
  ]
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.250.11.0/24",
    "10.250.12.0/24",
    "10.250.13.0/24"
  ]
}

variable "azs" {
  type = list(string)
  default = [
    "us-east-1b",
    "us-east-1c",
    "us-east-1d"
  ]
}
