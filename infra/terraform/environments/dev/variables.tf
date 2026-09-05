variable "aws_region" {
  type    = string
  default = "ap-southeast-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "azs" {
  type    = list(string)
  default = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "api_image" {
  description = "ECR image URI:tag once you've built and pushed one - e.g. \"<ecr_repository_url>:latest\" from `terraform output ecr_repository_url`"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
}

variable "worker_image" {
  type    = string
  default = "public.ecr.aws/docker/library/nginx:latest"
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_password" {
  type      = string
  sensitive = true
}
