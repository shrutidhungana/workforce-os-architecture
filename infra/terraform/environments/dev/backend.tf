# Remote state isn't wired up yet - there's no S3 bucket/DynamoDB lock table
# for it to point at. State is local for now.
#
# Once that bucket exists, uncomment and fill in:
#
# terraform {
#   backend "s3" {
#     bucket         = "workforce-os-terraform-state"
#     key            = "dev/terraform.tfstate"
#     region         = "ap-southeast-2"
#     dynamodb_table = "workforce-os-terraform-locks"
#     encrypt        = true
#   }
# }
