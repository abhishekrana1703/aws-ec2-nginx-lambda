variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "ami_id" {
  description = "Ubuntu 20.04 AMI"
  default     = "ami-051f7e7f6c2f40dc1"
}

variable "instance_type" {
  description = "EC2 Instance Type"
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key Pair name"
  default     = "aws-key"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "instance_name" {
  default = "WebServer"
}
