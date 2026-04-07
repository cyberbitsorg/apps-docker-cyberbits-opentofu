# =============================================================================
# Docker Apps for cyberbits.org — OpenTofu Root Module
# =============================================================================
#
# HOW TO ADD A NEW SITE
#   Nginx static site  → add an object to nginx_apps     in terraform.tfvars
#   WordPress site     → add an object to wordpress_apps  in terraform.tfvars
#   Nextcloud instance → add an object to nextcloud_apps  in terraform.tfvars
#
# BEFORE FIRST RUN
#   Ensure DNS A records for every domain point to this server.
#   Let's Encrypt will refuse to issue certificates without valid DNS,
#   and repeated failures cause a temporary ban.
#
# =============================================================================

# =============================================================================
# Traefik Network (shared by all app containers)
# =============================================================================

resource "docker_network" "traefik" {
  name   = var.traefik_network
  driver = "bridge"

  lifecycle {
    prevent_destroy = false
  }
}

# =============================================================================
# Traefik Reverse Proxy
# =============================================================================

module "traefik" {
  source = "./modules/traefik"

  remote_host               = var.remote_host
  traefik_version           = var.traefik_version
  traefik_network           = docker_network.traefik.name
  traefik_config_dir        = var.traefik_config_dir
  traefik_letsencrypt_email = var.admin_email
  traefik_dashboard_enabled = var.traefik_dashboard_enabled
  container_name            = var.traefik_container_name
  ssl_volume_name           = var.traefik_ssl_volume_name
  http_port                 = var.traefik_http_port
  https_port                = var.traefik_https_port
  docker_socket             = var.traefik_docker_socket
  docker_api_version        = var.traefik_docker_api_version
  restart_policy            = var.restart_policy
  security_opts             = var.security_opts
  memory_limit              = var.traefik_memory_limit
  cpu_shares                = var.traefik_cpu_shares
}

# =============================================================================
# Nginx Static Sites
# =============================================================================

module "nginx_apps" {
  source = "./modules/nginx-apps"

  for_each = { for app in var.nginx_apps : app.name => app }

  name              = each.value.name
  domain            = each.value.domain
  title             = each.value.title != null ? each.value.title : each.value.domain
  message           = each.value.message
  www_redirect      = each.value.www_redirect
  custom_nginx_conf = each.value.custom_nginx_conf

  base_app_dir         = var.base_app_dir
  traefik_network      = docker_network.traefik.name
  remote_host          = var.remote_host
  name_prefix          = var.nginx_name_prefix
  nginx_image          = var.nginx_image
  restart_policy       = var.restart_policy
  security_opts        = var.security_opts
  memory_limit         = each.value.memory_limit
  cpu_shares           = each.value.cpu_shares

  traefik_enabled       = var.traefik_router.enabled
  traefik_tls           = var.traefik_router.tls
  traefik_entrypoint    = var.traefik_router.entrypoint
  traefik_cert_resolver = var.traefik_router.cert_resolver
  traefik_middlewares   = var.traefik_router.middlewares

  depends_on = [module.traefik]
}

# =============================================================================
# WordPress Sites
# =============================================================================

module "wordpress_apps" {
  source = "./modules/wordpress-apps"

  for_each = { for app in var.wordpress_apps : app.name => app }

  name                    = each.value.name
  domain                  = each.value.domain
  db_name                 = each.value.db_name != null ? each.value.db_name : "${each.value.name}_wp"
  db_user                 = each.value.db_user != null ? each.value.db_user : "${each.value.name}_wp"
  table_prefix            = each.value.table_prefix
  www_redirect            = each.value.www_redirect
  php_memory_limit        = each.value.php_memory_limit
  php_upload_max_filesize = each.value.php_upload_max_filesize
  php_post_max_size       = each.value.php_post_max_size
  php_max_execution_time  = each.value.php_max_execution_time
  redis_maxmemory         = each.value.redis_maxmemory
  redis_maxmemory_policy  = each.value.redis_maxmemory_policy

  wordpress_image       = var.wordpress_images.wordpress
  wordpress_db_image    = var.wordpress_images.db
  wordpress_redis_image = var.wordpress_images.redis
  wordpress_nginx_image = var.wordpress_images.nginx
  wordpress_cli_image   = var.wordpress_images.cli

  db_host    = var.wordpress_db_host
  db_port    = var.wordpress_db_port
  redis_host = var.wordpress_redis_host
  redis_port = var.wordpress_redis_port
  redis_db   = var.wordpress_redis_db

  base_app_dir         = var.base_app_dir
  traefik_network      = docker_network.traefik.name
  remote_host          = var.remote_host
  name_prefix          = var.wordpress_name_prefix
  restart_policy       = var.restart_policy
  security_opts        = var.security_opts
  app_memory_limit     = each.value.app_memory_limit
  app_cpu_shares       = each.value.app_cpu_shares
  nginx_memory_limit   = each.value.nginx_memory_limit
  nginx_cpu_shares     = each.value.nginx_cpu_shares
  wpcli_memory_limit   = each.value.wpcli_memory_limit
  wpcli_cpu_shares     = each.value.wpcli_cpu_shares
  db_memory_limit      = each.value.db_memory_limit
  db_cpu_shares        = each.value.db_cpu_shares
  redis_memory_limit   = each.value.redis_memory_limit
  redis_cpu_shares     = each.value.redis_cpu_shares

  traefik_enabled       = var.traefik_router.enabled
  traefik_tls           = var.traefik_router.tls
  traefik_entrypoint    = var.traefik_router.entrypoint
  traefik_cert_resolver = var.traefik_router.cert_resolver
  traefik_middlewares   = var.traefik_router.middlewares

  depends_on = [module.traefik]
}

# =============================================================================
# Nextcloud Instances
# =============================================================================

module "nextcloud_apps" {
  source = "./modules/nextcloud-apps"

  for_each = { for app in var.nextcloud_apps : app.name => app }

  name                   = each.value.name
  domain                 = each.value.domain
  admin_user             = each.value.admin_user
  www_redirect           = each.value.www_redirect
  php_memory_limit       = each.value.php_memory_limit
  max_upload_size        = each.value.max_upload_size
  redis_maxmemory        = each.value.redis_maxmemory
  redis_maxmemory_policy = each.value.redis_maxmemory_policy

  nextcloud_image       = var.nextcloud_images.nextcloud
  nextcloud_db_image    = var.nextcloud_images.db
  nextcloud_redis_image = var.nextcloud_images.redis

  db_name         = var.nextcloud_db_name
  db_user         = var.nextcloud_db_user
  db_host         = var.nextcloud_db_host
  redis_host      = var.nextcloud_redis_host
  redis_port      = var.nextcloud_redis_port
  trusted_proxies = var.nextcloud_trusted_proxies

  base_app_dir         = var.base_app_dir
  traefik_network      = docker_network.traefik.name
  remote_host          = var.remote_host
  name_prefix          = var.nextcloud_name_prefix
  restart_policy       = var.restart_policy
  security_opts        = var.security_opts
  app_memory_limit     = each.value.app_memory_limit
  app_cpu_shares       = each.value.app_cpu_shares
  cron_memory_limit    = each.value.cron_memory_limit
  cron_cpu_shares      = each.value.cron_cpu_shares
  db_memory_limit      = each.value.db_memory_limit
  db_cpu_shares        = each.value.db_cpu_shares
  redis_memory_limit   = each.value.redis_memory_limit
  redis_cpu_shares     = each.value.redis_cpu_shares

  traefik_enabled       = var.traefik_router.enabled
  traefik_tls           = var.traefik_router.tls
  traefik_entrypoint    = var.traefik_router.entrypoint
  traefik_cert_resolver = var.traefik_router.cert_resolver
  traefik_middlewares   = var.traefik_router.middlewares

  depends_on = [module.traefik]
}
