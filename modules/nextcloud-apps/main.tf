# =============================================================================
# Nextcloud apps module main
# =============================================================================

# =============================================================================
# Random passwords
# =============================================================================

resource "random_password" "db_password" {
  length  = 32
  special = false
}

resource "random_password" "admin_password" {
  length  = 32
  special = false
}

resource "random_password" "redis_password" {
  length  = 32
  special = false
}

# =============================================================================
# Configuration files
# =============================================================================

resource "null_resource" "deploy_config" {
  triggers = {
    content_hash = sha256(local.env_content)
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

resource "docker_volume" "nextcloud_data" {
  name = local.nextcloud_volume_name
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
# Database container (PostgreSQL)
# =============================================================================

resource "docker_container" "db" {
  name  = local.db_container_name
  image = var.nextcloud_db_image

  restart = var.restart_policy

  memory      = var.db_memory_limit
  memory_swap = var.db_memory_limit
  cpu_shares  = var.db_cpu_shares

  security_opts = var.security_opts

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
    test         = local.db_healthcheck_test
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
  image = var.nextcloud_redis_image

  restart = var.restart_policy

  memory      = var.redis_memory_limit
  memory_swap = var.redis_memory_limit
  cpu_shares  = var.redis_cpu_shares

  security_opts = var.security_opts

  command = local.redis_command

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
# Nextcloud application container
# =============================================================================

resource "docker_container" "app" {
  name     = local.app_container_name
  image    = var.nextcloud_image
  hostname = local.app_container_name

  restart = var.restart_policy

  memory      = var.app_memory_limit
  memory_swap = var.app_memory_limit
  cpu_shares  = var.app_cpu_shares

  security_opts = var.security_opts

  env = local.app_env

  mounts {
    target = var.nextcloud_data_path
    source = docker_volume.nextcloud_data.name
    type   = local.mount_volume
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
    timeout      = var.app_healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.app_healthcheck_start_period
  }

  labels {
    label = local.traefik_enable_label
    value = var.traefik_enabled
  }

  labels {
    label = local.traefik_rule_label
    value = local.traefik_host_rule
  }

  labels {
    label = local.traefik_entrypoints_label
    value = var.traefik_entrypoint
  }

  labels {
    label = local.traefik_tls_label
    value = var.traefik_tls
  }

  labels {
    label = local.traefik_certresolver_label
    value = var.traefik_cert_resolver
  }

  labels {
    label = local.traefik_middlewares_label
    value = var.traefik_middlewares
  }

  labels {
    label = local.traefik_lb_port_label
    value = tostring(var.container_port)
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [
    docker_container.db,
    docker_container.redis,
    docker_network.internal,
    docker_volume.nextcloud_data
  ]
}

# =============================================================================
# Cron container
# =============================================================================

resource "docker_container" "cron" {
  name     = local.cron_container_name
  image    = var.nextcloud_image
  hostname = local.cron_container_name

  restart = var.restart_policy

  memory      = var.cron_memory_limit
  memory_swap = var.cron_memory_limit
  cpu_shares  = var.cron_cpu_shares

  security_opts = var.security_opts

  env = local.cron_env

  mounts {
    target = var.nextcloud_data_path
    source = docker_volume.nextcloud_data.name
    type   = local.mount_volume
  }

  networks_advanced {
    name = docker_network.internal.name
  }

  entrypoint = var.cron_entrypoint

  healthcheck {
    test         = var.cron_healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.healthcheck_start_period
  }

  lifecycle {
    ignore_changes = [log_driver, log_opts]
  }

  depends_on = [
    docker_container.db,
    docker_container.redis,
    docker_network.internal
  ]
}
