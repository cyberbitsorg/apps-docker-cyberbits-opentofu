# =============================================================================
# WordPress apps module locals
# =============================================================================

locals {
  app_dir          = "${var.base_app_dir}/wordpress-apps/${var.name}"
  db_password      = random_password.db_password.result
  db_root_password = random_password.db_root_password.result
  redis_password   = random_password.redis_password.result
  is_remote        = var.remote_host != ""

  # Resource names
  db_volume_name        = "${var.name_prefix}-${var.name}-db-data"
  wordpress_volume_name = "${var.name_prefix}-${var.name}-wordpress-data"
  redis_volume_name     = "${var.name_prefix}-${var.name}-redis-data"
  internal_network_name = "${var.name_prefix}-${var.name}-internal"
  db_container_name     = "${var.name_prefix}-${var.name}-db"
  redis_container_name  = "${var.name_prefix}-${var.name}-redis"
  app_container_name    = "${var.name_prefix}-${var.name}-app"
  nginx_container_name  = "${var.name_prefix}-${var.name}-nginx"
  wpcli_container_name  = "${var.name_prefix}-${var.name}-wpcli"
  router_name           = "${var.name_prefix}-${var.name}"

  # Mount type and network driver constants
  mount_bind     = "bind"
  mount_volume   = "volume"
  network_driver = "bridge"

  # Container commands
  db_command = [
    "--character-set-server=${var.db_charset}",
    "--collation-server=${var.db_collation}",
    "--skip-log-bin",
    "--local-infile=0",
    "--skip-symbolic-links",
    "--max-connections=${var.db_max_connections}"
  ]

  redis_command        = ["redis-server", "--maxmemory", var.redis_maxmemory, "--maxmemory-policy", var.redis_maxmemory_policy, "--requirepass", local.redis_password]
  redis_healthcheck_test = ["CMD", "redis-cli", "-a", local.redis_password, "ping"]

  # Computed bind mount source paths
  php_ini_source    = "${local.app_dir}/php-uploads.ini"
  nginx_conf_source = "${local.app_dir}/nginx/wordpress.conf"

  # Shared Redis defines (used by both WordPress app and WP-CLI)
  redis_config_defines = "define('WP_REDIS_HOST', '${var.redis_host}'); define('WP_REDIS_PORT', ${var.redis_port}); define('WP_REDIS_DATABASE', ${var.redis_db}); define('WP_REDIS_AUTH', '${local.redis_password}'); define('WP_CACHE', ${var.wp_cache});"

  # WordPress config extras
  wordpress_config_extra = "define('DISALLOW_FILE_EDIT', ${var.wp_disallow_file_edit}); define('FORCE_SSL_ADMIN', ${var.wp_force_ssl_admin}); define('WP_AUTO_UPDATE_CORE', '${var.wp_auto_update_core}'); define('WP_MEMORY_LIMIT', '${var.php_memory_limit}'); ${local.redis_config_defines}"
  wpcli_config_extra     = local.redis_config_defines

  # Environment variable arrays
  db_env = [
    "MYSQL_ROOT_PASSWORD=${local.db_root_password}",
    "MYSQL_DATABASE=${var.db_name}",
    "MYSQL_USER=${var.db_user}",
    "MYSQL_PASSWORD=${local.db_password}"
  ]

  app_env = [
    "WORDPRESS_DB_HOST=${var.db_host}:${var.db_port}",
    "WORDPRESS_DB_NAME=${var.db_name}",
    "WORDPRESS_DB_USER=${var.db_user}",
    "WORDPRESS_DB_PASSWORD=${local.db_password}",
    "WORDPRESS_TABLE_PREFIX=${var.table_prefix}",
    "PHP_UPLOAD_MAX_FILESIZE=${var.php_upload_max_filesize}",
    "PHP_POST_MAX_SIZE=${var.php_post_max_size}",
    "WORDPRESS_AUTH_KEY=${random_password.wp_auth_key.result}",
    "WORDPRESS_SECURE_AUTH_KEY=${random_password.wp_secure_auth_key.result}",
    "WORDPRESS_LOGGED_IN_KEY=${random_password.wp_logged_in_key.result}",
    "WORDPRESS_NONCE_KEY=${random_password.wp_nonce_key.result}",
    "WORDPRESS_AUTH_SALT=${random_password.wp_auth_salt.result}",
    "WORDPRESS_SECURE_AUTH_SALT=${random_password.wp_secure_auth_salt.result}",
    "WORDPRESS_LOGGED_IN_SALT=${random_password.wp_logged_in_salt.result}",
    "WORDPRESS_NONCE_SALT=${random_password.wp_nonce_salt.result}",
    "WORDPRESS_CONFIG_EXTRA=${local.wordpress_config_extra}"
  ]

  wpcli_env = [
    "WORDPRESS_DB_HOST=${var.db_host}:${var.db_port}",
    "WORDPRESS_DB_NAME=${var.db_name}",
    "WORDPRESS_DB_USER=${var.db_user}",
    "WORDPRESS_DB_PASSWORD=${local.db_password}",
    "WORDPRESS_TABLE_PREFIX=${var.table_prefix}",
    "WORDPRESS_CONFIG_EXTRA=${local.wpcli_config_extra}"
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

  env_content = templatefile("${path.module}/templates/wordpress.env.tftpl", {
    db_root_password    = random_password.db_root_password.result
    db_name             = var.db_name
    db_user             = var.db_user
    db_password         = random_password.db_password.result
    table_prefix        = var.table_prefix
    wp_auth_key         = random_password.wp_auth_key.result
    wp_secure_auth_key  = random_password.wp_secure_auth_key.result
    wp_logged_in_key    = random_password.wp_logged_in_key.result
    wp_nonce_key        = random_password.wp_nonce_key.result
    wp_auth_salt        = random_password.wp_auth_salt.result
    wp_secure_auth_salt = random_password.wp_secure_auth_salt.result
    wp_logged_in_salt   = random_password.wp_logged_in_salt.result
    wp_nonce_salt       = random_password.wp_nonce_salt.result
  })
  nginx_conf_content = templatefile("${path.module}/templates/wordpress-nginx.conf.tftpl", {
    app_hostname            = local.router_name
    php_upload_max_filesize = var.php_upload_max_filesize
  })
  php_ini_content = templatefile("${path.module}/templates/php-uploads.ini.tftpl", {
    php_upload_max_filesize = var.php_upload_max_filesize
    php_post_max_size       = var.php_post_max_size
    php_max_execution_time  = var.php_max_execution_time
    php_memory_limit        = var.php_memory_limit
  })

  remote_cmd = <<-EOT
    ssh ${var.remote_host} 'mkdir -p ${local.app_dir}/nginx'
    printf '%s' '${base64encode(local.env_content)}' | ssh ${var.remote_host} 'base64 -d > ${local.app_dir}/.env && chmod 600 ${local.app_dir}/.env'
    printf '%s' '${base64encode(local.nginx_conf_content)}' | ssh ${var.remote_host} 'base64 -d > ${local.app_dir}/nginx/wordpress.conf'
    printf '%s' '${base64encode(local.php_ini_content)}' | ssh ${var.remote_host} 'base64 -d > ${local.app_dir}/php-uploads.ini'
  EOT
  local_cmd  = <<-EOT
    mkdir -p ${local.app_dir}/nginx
    printf '%s' '${base64encode(local.env_content)}' | base64 -d > ${local.app_dir}/.env && chmod 600 ${local.app_dir}/.env
    printf '%s' '${base64encode(local.nginx_conf_content)}' | base64 -d > ${local.app_dir}/nginx/wordpress.conf
    printf '%s' '${base64encode(local.php_ini_content)}' | base64 -d > ${local.app_dir}/php-uploads.ini
  EOT
}
