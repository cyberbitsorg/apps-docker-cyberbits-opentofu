# =============================================================================
# Nginx apps module outputs
# =============================================================================

output "container_name" {
  description = "Name of the Nginx container"
  value       = docker_container.nginx.name
}

output "container_id" {
  description = "ID of the Nginx container"
  value       = docker_container.nginx.id
}

output "app_dir" {
  description = "Path to application directory on host"
  value       = local.app_dir
}

output "data_dir" {
  description = "Path to the webroot directory on the host"
  value       = local.data_dir
}

output "domain" {
  description = "Domain name of the application"
  value       = var.domain
}
