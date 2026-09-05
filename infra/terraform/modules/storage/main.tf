resource "aws_s3_bucket" "documents" {
  bucket = "${var.environment}-workforce-os-documents"

  tags = {
    Environment = var.environment
    Purpose     = "employee/document uploads"
  }
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "documents" {
  bucket = aws_s3_bucket.documents.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Stays private - CloudFront reaches this via Origin Access Control, not a
# public bucket policy. The CloudFront distribution itself is a follow-up
# (needs the web build output and OAC wiring) and isn't provisioned yet.
resource "aws_s3_bucket" "static_assets" {
  bucket = "${var.environment}-workforce-os-static-assets"

  tags = {
    Environment = var.environment
    Purpose     = "web app static assets served via CloudFront"
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
