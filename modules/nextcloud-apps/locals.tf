# =============================================================================
# Nextcloud apps module locals
# =============================================================================

locals {
  app_dir        = "${var.base_app_dir}/nextcloud-apps/${var.name}"
  db_password    = random_password.db_password.result
  admin_password = random_password.admin_password.result
  redis_password = random_password.redis_password.result
  is_remote      = var.remote_host != ""

  # Resource names
  db_volume_name        = "${var.name_prefix}-${var.name}-db-data"
  nextcloud_volume_name = "${var.name_prefix}-${var.name}-nextcloud-data"
  redis_volume_name     = "${var.name_prefix}-${var.name}-redis-data"
  internal_network_name = "${var.name_prefix}-${var.name}-internal"
  db_container_name     = "${var.name_prefix}-${var.name}-db"
  redis_container_name  = "${var.name_prefix}-${var.name}-redis"
  app_container_name    = "${var.name_prefix}-${var.name}-app"
  cron_container_name   = "${var.name_prefix}-${var.name}-cron"
  router_name           = "${var.name_prefix}-${var.name}"

  # Mount type and network driver constants
  mount_bind     = "bind"
  mount_volume   = "volume"
  network_driver = "bridge"

  # Container commands
  redis_command          = ["redis-server", "--maxmemory", var.redis_maxmemory, "--maxmemory-policy", var.redis_maxmemory_policy, "--requirepass", local.redis_password]
  redis_healthcheck_test = ["CMD", "redis-cli", "-a", local.redis_password, "ping"]

  # Healthcheck commands
  db_healthcheck_test = ["CMD-SHELL", "pg_isready -U ${var.db_user}"]

  # Environment variable arrays
  db_env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${local.db_password}"
  ]

  app_env = [
    "POSTGRES_HOST=${var.db_host}",
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${local.db_password}",
    "NEXTCLOUD_ADMIN_USER=${var.admin_user}",
    "NEXTCLOUD_ADMIN_PASSWORD=${local.admin_password}",
    "NEXTCLOUD_TRUSTED_DOMAINS=${var.domain}",
    "OVERWRITEPROTOCOL=${var.overwrite_protocol}",
    "OVERWRITEHOST=${var.domain}",
    "TRUSTED_PROXIES=${var.trusted_proxies}",
    "REDIS_HOST=${var.redis_host}",
    "REDIS_HOST_PORT=${var.redis_port}",
    "REDIS_HOST_PASSWORD=${local.redis_password}",
    "PHP_MEMORY_LIMIT=${var.php_memory_limit}",
    "PHP_UPLOAD_LIMIT=${var.max_upload_size}"
  ]

  cron_env = [
    "POSTGRES_HOST=${var.db_host}",
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${local.db_password}"
  ]

  # Traefik routing rule
  traefik_host_rule = var.www_redirect ? "Host(`${var.domain}`) || Host(`www.${var.domain}`)" : "Host(`${var.domain}`)"

  # Traefik label keys
  traefik_enable_label       = "traefik.enable"
  traefik_rule_label         = "traefik.http.routers.${local.router_name}.rule"
  traefik_entrypoints_label  = "traefik.http.routers.${local.router_name}.entrypoints"
  traefik_tls_label          = "traefik.http.routers.${local.router_name}.tls"
  traefik_certresolver_label = "traefik.http.routers.${local.router_name}.tls.certresolver"
  traefik_middlewares_label  = "traefik.http.routers.${local.router_name}.middlewares"
  traefik_lb_port_label      = "traefik.http.services.${local.router_name}.loadbalancer.server.port"

  env_content = templatefile("${path.module}/templates/nextcloud.env.tftpl", {
    db_password    = random_password.db_password.result
    admin_user     = var.admin_user
    admin_password = random_password.admin_password.result
  })

  remote_cmd = <<-EOT
    ssh ${var.remote_host} 'mkdir -p ${local.app_dir}'
    printf '%s' '${base64encode(local.env_content)}' | ssh ${var.remote_host} 'base64 -d > ${local.app_dir}/.env && chmod 600 ${local.app_dir}/.env'
  EOT
  local_cmd  = <<-EOT
    mkdir -p ${local.app_dir}
    printf '%s' '${base64encode(local.env_content)}' | base64 -d > ${local.app_dir}/.env && chmod 600 ${local.app_dir}/.env
  EOT
}
