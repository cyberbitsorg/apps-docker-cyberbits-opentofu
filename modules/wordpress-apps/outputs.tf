# =============================================================================
# WordPress apps module outputs
# =============================================================================

output "app_name" {
  description = "Name of the WordPress application"
  value       = var.name
}

output "domain" {
  description = "Domain name of the application"
  value       = var.domain
}

output "app_dir" {
  description = "Path to application directory on host"
  value       = local.app_dir
}

output "env_file" {
  description = "Path to the environment file"
  value       = "${local.app_dir}/.env"
}

output "db_container" {
  description = "Name of the database container"
  value       = docker_container.db.name
}

output "wordpress_container" {
  description = "Name of the WordPress container"
  value       = docker_container.wordpress.name
}

output "nginx_container" {
  description = "Name of the Nginx container"
  value       = docker_container.nginx.name
}

output "redis_container" {
  description = "Name of the Redis container"
  value       = docker_container.redis.name
}
