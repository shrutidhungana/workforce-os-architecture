variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_security_group_id" {
  type = string
}

variable "app_security_group_id" {
  type = string
}

variable "data_security_group_id" {
  type = string
}

variable "ecs_task_execution_role_arn" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "app_port" {
  type    = number
  default = 3000
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "api_image" {
  description = "Placeholder image until a real one is pushed to the ECR repo this module creates"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
}

variable "worker_image" {
  description = "Usually the same image as api_image (same codebase) - worker_command is what makes it run as a worker"
  type        = string
  default     = "public.ecr.aws/docker/library/nginx:latest"
}

variable "worker_command" {
  description = "Container command override that runs the image as a queue worker instead of the API server - replace with the real entrypoint once the app defines one"
  type        = list(string)
  default     = ["node", "dist/worker.js"]
}

variable "redis_image" {
  type    = string
  default = "public.ecr.aws/docker/library/redis:7-alpine"
}

variable "api_cpu" {
  type    = number
  default = 256
}

variable "api_memory" {
  type    = number
  default = 512
}

variable "worker_cpu" {
  type    = number
  default = 256
}

variable "worker_memory" {
  type    = number
  default = 512
}

variable "redis_cpu" {
  type    = number
  default = 256
}

variable "redis_memory" {
  type    = number
  default = 512
}

variable "api_log_group_name" {
  type = string
}

variable "worker_log_group_name" {
  type = string
}

variable "redis_log_group_name" {
  type = string
}
