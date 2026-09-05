output "alb_dns_name" {
  value = module.compute.alb_dns_name
}

output "rds_endpoint" {
  value = module.database.endpoint
}

output "documents_bucket_name" {
  value = module.storage.documents_bucket_name
}

output "ecs_cluster_name" {
  value = module.compute.cluster_name
}

output "ecr_repository_url" {
  value = module.compute.ecr_repository_url
}
