# =============================================================================
# Nginx apps module main
# =============================================================================

# =============================================================================
# Configuration files
# =============================================================================

resource "null_resource" "deploy_config" {
  triggers = {
    content_hash = sha256(local.nginx_conf_content)
  }

  provisioner "local-exec" {
    command = local.is_remote ? local.remote_cmd : local.local_cmd
  }
}

# =============================================================================
# Nginx container
# =============================================================================

resource "docker_container" "nginx" {
  name  = local.container_name
  image = var.nginx_image

  restart = var.restart_policy

  memory      = var.memory_limit
  memory_swap = var.memory_limit
  cpu_shares  = var.cpu_shares

  security_opts = var.security_opts

  mounts {
    target = var.webroot_path
    source = local.data_dir
    type   = local.mount_bind
  }

  dynamic "mounts" {
    for_each = var.custom_nginx_conf ? [] : [1]
    content {
      target    = var.nginx_conf_path
      source    = local.nginx_default_conf_source
      type      = local.mount_bind
      read_only = true
    }
  }

  dynamic "mounts" {
    for_each = var.custom_nginx_conf ? [1] : []
    content {
      target    = var.nginx_conf_path
      source    = local.nginx_custom_conf_source
      type      = local.mount_bind
      read_only = true
    }
  }

  mounts {
    target    = var.localtime_path
    source    = var.localtime_path
    type      = local.mount_bind
    read_only = true
  }

  networks_advanced {
    name = var.traefik_network
  }

  healthcheck {
    test         = var.healthcheck_test
    interval     = var.healthcheck_interval
    timeout      = var.healthcheck_timeout
    retries      = var.healthcheck_retries
    start_period = var.healthcheck_start_period
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

  depends_on = [null_resource.deploy_config]
}
