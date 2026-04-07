# =============================================================================
# Nextcloud apps module outputs
# =============================================================================

output "app_name" {
  description = "Name of the Nextcloud application"
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

output "app_container" {
  description = "Name of the Nextcloud application container"
  value       = docker_container.app.name
}

output "redis_container" {
  description = "Name of the Redis container"
  value       = docker_container.redis.name
}

output "cron_container" {
  description = "Name of the cron container"
  value       = docker_container.cron.name
}

output "admin_credentials" {
  description = "Admin credentials for Nextcloud (sensitive)"
  value = {
    username = var.admin_user
    password = local.admin_password
  }
  sensitive = true
}

output "setup_info" {
  description = "Where to find credentials after deploy"
  value = {
    env_file     = "${local.app_dir}/.env"
    tofu_command = "tofu output -json nextcloud_credentials"
  }
}
