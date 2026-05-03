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
  default = "Dev"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "desired_capacity" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4
}

variable "bucket_name" {
  type    = string
  default = "group2-dev-bucket-terraform"
}

variable "my_ip" {
  type        = string
  description = "Your local machine public IP in CIDR format, e.g. 203.0.113.5/32"
}

variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
}

variable "key_name" {
  type    = string
  default = "vockey"
}
