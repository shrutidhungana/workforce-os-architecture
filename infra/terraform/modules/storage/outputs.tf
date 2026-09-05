output "documents_bucket_name" {
  value = aws_s3_bucket.documents.bucket
}

output "documents_bucket_arn" {
  value = aws_s3_bucket.documents.arn
}

output "static_assets_bucket_name" {
  value = aws_s3_bucket.static_assets.bucket
}

output "static_assets_bucket_arn" {
  value = aws_s3_bucket.static_assets.arn
}
