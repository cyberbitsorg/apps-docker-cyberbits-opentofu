# =============================================================================
# WordPress apps module main
# =============================================================================

# =============================================================================
# Random passwords and keys
# =============================================================================

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "random_password" "db_root_password" {
  length  = 32
  special = false
}

resource "random_password" "redis_password" {
  length  = 32
  special = false
}

resource "random_password" "wp_keys" {
  for_each = toset([
    "auth_key", "secure_auth_key", "logged_in_key", "nonce_key",
    "auth_salt", "secure_auth_salt", "logged_in_salt", "nonce_salt",
  ])
  length  = 32
  special = false
}

# Preserve the values generated before wp_keys was consolidated into one
# for_each resource, so logins and nonces survive the refactor.
moved {
  from = random_password.wp_auth_key
  to   = random_password.wp_keys["auth_key"]
}
moved {
  from = random_password.wp_secure_auth_key
  to   = random_password.wp_keys["secure_auth_key"]
}
moved {
  from = random_password.wp_logged_in_key
  to   = random_password.wp_keys["logged_in_key"]
}
moved {
  from = random_password.wp_nonce_key
  to   = random_password.wp_keys["nonce_key"]
}
moved {
  from = random_password.wp_auth_salt
  to   = random_password.wp_keys["auth_salt"]
}
moved {
  from = random_password.wp_secure_auth_salt
  to   = random_password.wp_keys["secure_auth_salt"]
}
moved {
  from = random_password.wp_logged_in_salt
  to   = random_password.wp_keys["logged_in_salt"]
}
moved {
  from = random_password.wp_nonce_salt
  to   = random_password.wp_keys["nonce_salt"]
}

# =============================================================================
# Configuration files
# =============================================================================

resource "null_resource" "deploy_config" {
  triggers = {
    content_hash = sha256(join("|", [local.env_content, local.nginx_conf_content, local.php_ini_content]))
  }

  provisioner "local-exec" {
    command = local.is_remote ? local.remote_cmd : local.local_cmd
  }
}

# =============================================================================
# Docker volumes
# =============================================================================

resource "docker_volume" "db_data" {
  name = local.db_volume_name
}

resource "docker_volume" "wordpress_data" {
  name = local.wordpress_volume_name
}

resource "docker_volume" "redis_data" {
  name = local.redis_volume_name
}

# =============================================================================
# Docker network (internal)
# =============================================================================

resource "docker_network" "internal" {
  name     = local.internal_network_name
  driver   = local.network_driver
  internal = true
}

# =============================================================================
# Database container (MariaDB)
# =============================================================================

resource "docker_container" "db" {
  name  = local.db_container_name
  image = var.wordpress_db_image

  restart = var.restart_policy

  memory      = var.db_memory_limit
  memory_swap = var.db_memory_limit
  cpu_shares  = var.db_cpu_shares

  security_opts = var.security_opts

  command = local.db_command

  env = local.db_env

  mounts {
    target = var.db_data_path
    source = docker_volume.db_data.name
    type   = local.mount_volume
  }

  networks_advanced {
    name    = docker_network.internal.name
    aliases = ["db"]
  }

  healthcheck {
    test         = var.db_healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.db_healthcheck_retries
    start_period = var.db_healthcheck_start_period
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [docker_network.internal, docker_volume.db_data]
}

# =============================================================================
# Redis container
# =============================================================================

resource "docker_container" "redis" {
  name  = local.redis_container_name
  image = var.wordpress_redis_image

  restart = var.restart_policy

  memory      = var.redis_memory_limit
  memory_swap = var.redis_memory_limit
  cpu_shares  = var.redis_cpu_shares

  security_opts = var.security_opts

  command = local.redis_command

  env = ["REDIS_PASSWORD=${local.redis_password}"]

  mounts {
    target = var.redis_data_path
    source = docker_volume.redis_data.name
    type   = local.mount_volume
  }

  networks_advanced {
    name    = docker_network.internal.name
    aliases = ["redis"]
  }

  healthcheck {
    test         = local.redis_healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.healthcheck_start_period
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [docker_network.internal, docker_volume.redis_data]
}

# =============================================================================
# WordPress container (PHP-FPM)
# =============================================================================

resource "docker_container" "wordpress" {
  name     = local.app_container_name
  image    = var.wordpress_image
  hostname = local.router_name

  restart = var.restart_policy

  memory      = var.app_memory_limit
  memory_swap = var.app_memory_limit
  cpu_shares  = var.app_cpu_shares

  security_opts = var.security_opts

  env = local.app_env

  mounts {
    target = var.wordpress_data_path
    source = docker_volume.wordpress_data.name
    type   = local.mount_volume
  }

  mounts {
    target    = var.php_ini_path
    source    = local.php_ini_source
    type      = local.mount_bind
    read_only = true
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  host {
    host = var.domain
    ip   = "host-gateway"
  }

  networks_advanced {
    name = docker_network.internal.name
  }

  networks_advanced {
    name = var.traefik_network
  }

  healthcheck {
    test         = var.app_healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.app_healthcheck_start_period
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [
    docker_container.db,
    docker_container.redis,
    docker_network.internal,
    docker_volume.wordpress_data,
    null_resource.deploy_config
  ]
}

# =============================================================================
# Nginx container (reverse proxy for WordPress)
# =============================================================================

resource "docker_container" "nginx" {
  name  = local.nginx_container_name
  image = var.wordpress_nginx_image

  restart = var.restart_policy

  memory      = var.nginx_memory_limit
  memory_swap = var.nginx_memory_limit
  cpu_shares  = var.nginx_cpu_shares

  security_opts = var.security_opts

  mounts {
    target    = var.wordpress_data_path
    source    = docker_volume.wordpress_data.name
    type      = local.mount_volume
    read_only = true
  }

  mounts {
    target    = var.nginx_conf_path
    source    = local.nginx_conf_source
    type      = local.mount_bind
    read_only = true
  }

  networks_advanced {
    name = docker_network.internal.name
  }

  networks_advanced {
    name = var.traefik_network
  }

  healthcheck {
    test         = var.nginx_healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.healthcheck_start_period
  }

  dynamic "labels" {
    for_each = local.traefik_labels
    content {
      label = labels.key
      value = labels.value
    }
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [
    docker_container.wordpress,
    docker_network.internal,
    null_resource.deploy_config
  ]
}

# =============================================================================
# WP-CLI container (management tool)
# =============================================================================

resource "docker_container" "wpcli" {
  name  = local.wpcli_container_name
  image = var.wordpress_cli_image

  restart = var.restart_policy

  memory      = var.wpcli_memory_limit
  memory_swap = var.wpcli_memory_limit
  cpu_shares  = var.wpcli_cpu_shares

  security_opts = var.security_opts

  env = local.wpcli_env

  mounts {
    target = var.wordpress_data_path
    source = docker_volume.wordpress_data.name
    type   = local.mount_volume
  }

  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }

  host {
    host = var.domain
    ip   = "host-gateway"
  }

  networks_advanced {
    name = docker_network.internal.name
  }

  networks_advanced {
    name = var.traefik_network
  }

  entrypoint = var.wpcli_entrypoint

  healthcheck {
    test         = var.wpcli_healthcheck_test
    interval     = var.wpcli_healthcheck_interval
    timeout      = var.wpcli_healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.wpcli_healthcheck_start_period
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [
    docker_container.db,
    docker_container.wordpress,
    docker_network.internal
  ]
}
