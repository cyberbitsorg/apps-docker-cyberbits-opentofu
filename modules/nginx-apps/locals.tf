# =============================================================================
# Nginx apps module locals
# =============================================================================

locals {
  app_dir   = "${var.base_app_dir}/nginx-apps/${var.name}"
  is_remote = var.remote_host != ""

  # Resource names
  container_name = "${var.name_prefix}-${var.name}"
  router_name    = "${var.name_prefix}-${var.name}"

  # Mount type constant
  mount_bind = "bind"

  # Computed source paths for bind mounts
  data_dir                  = "${local.app_dir}/data"
  nginx_default_conf_source = "${local.app_dir}/nginx-default.conf"
  nginx_custom_conf_source  = "${local.app_dir}/nginx.conf"

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

  nginx_conf_content = var.custom_nginx_conf ? "" : templatefile("${path.module}/templates/nginx-default.conf.tftpl", {})
  index_html_content = templatefile("${path.module}/templates/index.html.tftpl", {
    title   = var.title
    message = var.message
    domain  = var.domain
  })

  nginx_conf_cmd_remote = var.custom_nginx_conf ? "" : "printf '%s' '${base64encode(local.nginx_conf_content)}' | ssh ${var.remote_host} 'base64 -d > ${local.app_dir}/nginx-default.conf'"
  nginx_conf_cmd_local  = var.custom_nginx_conf ? "" : "printf '%s' '${base64encode(local.nginx_conf_content)}' | base64 -d > ${local.app_dir}/nginx-default.conf"

  remote_cmd = <<-EOT
    ssh ${var.remote_host} 'mkdir -p ${local.app_dir}/data'
    printf '%s' '${base64encode(local.index_html_content)}' | ssh ${var.remote_host} 'test -f ${local.app_dir}/data/index.html || base64 -d > ${local.app_dir}/data/index.html'
    ${local.nginx_conf_cmd_remote}
  EOT
  local_cmd  = <<-EOT
    mkdir -p ${local.app_dir}/data
    test -f ${local.app_dir}/data/index.html || printf '%s' '${base64encode(local.index_html_content)}' | base64 -d > ${local.app_dir}/data/index.html
    ${local.nginx_conf_cmd_local}
  EOT
}