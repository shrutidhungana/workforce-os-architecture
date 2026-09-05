variable "environment" {
  type = string
}

variable "documents_bucket_arn" {
  description = "ARN of the S3 documents bucket the task role is allowed to read/write"
  type        = string
}
