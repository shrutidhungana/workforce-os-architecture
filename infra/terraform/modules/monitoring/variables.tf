variable "environment" {
  type = string
}

variable "retention_in_days" {
  description = "Short retention keeps CloudWatch Logs cheap - this is a portfolio project, not a compliance-bound system"
  type        = number
  default     = 14
}
