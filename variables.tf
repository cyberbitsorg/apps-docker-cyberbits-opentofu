# =============================================================================
# Variables
# =============================================================================
#
# WHERE TO ADD THINGS:
#   New sites/apps  → terraform.tfvars  (nginx_apps / wordpress_apps / nextcloud_apps)
#   Image versions  → terraform.tfvars  (wordpress_images / nextcloud_images / nginx_image)
#   Global tuning   → here (defaults are production-ready; change only if needed)
#   Module internals (mount paths, healthchecks) → the relevant module's variables.tf
#
# =============================================================================

# =============================================================================
# CONNECTION
# =============================================================================
# Where to deploy. Set docker_host + remote_host together for SSH deployments.
# Both reference the same server but are used by different subsystems:
#   docker_host  → Docker provider (image pulls, container management)
#   remote_host  → SSH provisioner (config file uploads via SCP/bash)

variable "docker_host" {
  description = "Docker daemon connection string (e.g. ssh://user@host or unix:///var/run/docker.sock)"
  type        = string
  default     = "unix:///var/run/docker.sock"
}

variable "remote_host" {
  description = "SSH target for provisioners, format: user@host (leave empty for local deployment)"
  type        = string
  default     = ""
}

# =============================================================================
# GLOBAL SETTINGS
# =============================================================================
# Apply across all deployed applications.

variable "admin_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "support@cyberbits.org"
}

variable "base_app_dir" {
  description = "Root directory on the host for all application data (e.g. /opt)"
  type        = string
  default     = "/opt"
}

variable "restart_policy" {
  description = "Docker restart policy applied to all containers (unless-stopped | always | on-failure | no)"
  type        = string
  default     = "unless-stopped"
  validation {
    condition     = contains(["unless-stopped", "always", "on-failure", "no"], var.restart_policy)
    error_message = "restart_policy must be one of: no, always, on-failure, unless-stopped."
  }
}

variable "security_opts" {
  description = "Docker security options applied to all containers"
  type        = list(string)
  default     = ["no-new-privileges:true"]
}

# =============================================================================
# TRAEFIK GATEWAY
# =============================================================================
# Traefik is the single reverse proxy and SSL terminator. One instance per server.
# Most defaults are fine for a standard single-server setup.

variable "traefik_network" {
  description = "Name of the shared Docker bridge network Traefik and app containers join"
  type        = string
  default     = "traefik"
}

variable "traefik_version" {
  description = "Traefik Docker image tag"
  type        = string
  default     = "v3.6"
}

variable "traefik_config_dir" {
  description = "Directory on the host that holds traefik.yml and the config/ subdirectory"
  type        = string
  default     = "/opt/traefik"
}

variable "traefik_container_name" {
  description = "Docker container name for the Traefik gateway"
  type        = string
  default     = "gw-traefik"
}

variable "traefik_ssl_volume_name" {
  description = "Docker volume name for Let's Encrypt certificate storage"
  type        = string
  default     = "gw-traefik-ssl"
}

variable "traefik_dashboard_enabled" {
  description = "Enable the Traefik dashboard (disable in production)"
  type        = bool
  default     = false
}

variable "traefik_memory_limit" {
  description = "Memory limit for the Traefik container in MiB (0 = unlimited)"
  type        = number
  default     = 128
}

variable "traefik_cpu_shares" {
  description = "CPU shares for the Traefik container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 512
}

variable "traefik_http_port" {
  description = "Host port bound for HTTP (port 80 redirect)"
  type        = number
  default     = 80
  validation {
    condition     = var.traefik_http_port >= 1 && var.traefik_http_port <= 65535
    error_message = "traefik_http_port must be between 1 and 65535."
  }
}

variable "traefik_https_port" {
  description = "Host port bound for HTTPS traffic"
  type        = number
  default     = 443
  validation {
    condition     = var.traefik_https_port >= 1 && var.traefik_https_port <= 65535
    error_message = "traefik_https_port must be between 1 and 65535."
  }
}

# =============================================================================
# TRAEFIK ROUTING
# =============================================================================
# These label values are applied to every app container so Traefik knows how
# to route and secure them. Override in terraform.tfvars if you use a different
# ACME resolver name, entrypoint name, or middleware set.

variable "traefik_router" {
  description = "Traefik routing settings applied to all app containers"
  type = object({
    enabled       = optional(string, "true")
    tls           = optional(string, "true")
    entrypoint    = optional(string, "websecure")
    cert_resolver = optional(string, "letsencrypt")
    middlewares   = optional(string, "security-headers@file,rate-limit@file,compress@file")
  })
  default = {}
}

# =============================================================================
# NGINX STATIC SITES
# =============================================================================
# Add new static sites by appending objects to nginx_apps in terraform.tfvars.

variable "nginx_name_prefix" {
  description = "Short prefix used in container and volume names for Nginx apps (e.g. nx)"
  type        = string
  default     = "nx"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.nginx_name_prefix))
    error_message = "nginx_name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "nginx_image" {
  description = "Nginx Docker image used for static sites"
  type        = string
  default     = "nginx:alpine"
}

variable "nginx_apps" {
  description = <<-EOD
    List of Nginx static site definitions.
    Required fields : name, domain
    Optional fields : title, message, www_redirect, custom_nginx_conf
  EOD
  type = list(object({
    name              = string
    domain            = string
    title             = optional(string, null)
    message           = optional(string, "Website deployed with OpenTofu + Docker")
    www_redirect      = optional(bool, false)
    custom_nginx_conf = optional(bool, false)
    memory_limit      = optional(number, 64)
    cpu_shares        = optional(number, 512)
  }))
  default = []
  validation {
    condition     = alltrue([for app in var.nginx_apps : can(regex("^[a-z0-9][a-z0-9-]*$", app.name))])
    error_message = "Each nginx_apps entry name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
  validation {
    condition     = alltrue([for app in var.nginx_apps : can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", app.domain))])
    error_message = "Each nginx_apps entry domain must be a valid fully-qualified domain name."
  }
}

# =============================================================================
# WORDPRESS SITES
# =============================================================================
# Add new WordPress sites by appending objects to wordpress_apps in terraform.tfvars.

variable "wordpress_name_prefix" {
  description = "Short prefix used in container, volume and network names for WordPress apps (e.g. wp)"
  type        = string
  default     = "wp"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.wordpress_name_prefix))
    error_message = "wordpress_name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "wordpress_images" {
  description = "Docker images for the WordPress stack. Override individual keys to pin versions."
  type = object({
    wordpress = optional(string, "wordpress:6-fpm-alpine")
    db        = optional(string, "mariadb:11")
    redis     = optional(string, "redis:7-alpine")
    nginx     = optional(string, "nginx:alpine")
    cli       = optional(string, "wordpress:cli")
  })
  default = {}
}

variable "wordpress_db_host" {
  description = "Hostname of the MariaDB service within the WordPress internal network"
  type        = string
  default     = "db"
}

variable "wordpress_db_port" {
  description = "Port the MariaDB service listens on"
  type        = number
  default     = 3306
}

variable "wordpress_redis_host" {
  description = "Hostname of the Redis service within the WordPress internal network"
  type        = string
  default     = "redis"
}

variable "wordpress_redis_port" {
  description = "Port the Redis service listens on"
  type        = number
  default     = 6379
}

variable "wordpress_redis_db" {
  description = "Redis database index used by WordPress"
  type        = number
  default     = 0
}

variable "wordpress_apps" {
  description = <<-EOD
    List of WordPress site definitions.
    Required fields : name, domain, db_name, db_user
    Optional fields : table_prefix, www_redirect, php_memory_limit,
                      php_upload_max_filesize, php_post_max_size,
                      php_max_execution_time, redis_maxmemory, redis_maxmemory_policy
  EOD
  type = list(object({
    name                    = string
    domain                  = string
    db_name                 = optional(string, null)
    db_user                 = optional(string, null)
    table_prefix            = optional(string, "wp_")
    www_redirect            = optional(bool, false)
    php_memory_limit        = optional(string, "512M")
    php_upload_max_filesize = optional(string, "64M")
    php_post_max_size       = optional(string, "64M")
    php_max_execution_time  = optional(number, 300)
    redis_maxmemory         = optional(string, "128mb")
    redis_maxmemory_policy  = optional(string, "allkeys-lru")
    app_memory_limit        = optional(number, 512)
    app_cpu_shares          = optional(number, 1024)
    nginx_memory_limit      = optional(number, 128)
    nginx_cpu_shares        = optional(number, 256)
    wpcli_memory_limit      = optional(number, 128)
    wpcli_cpu_shares        = optional(number, 256)
    db_memory_limit         = optional(number, 512)
    db_cpu_shares           = optional(number, 512)
    redis_memory_limit      = optional(number, 256)
    redis_cpu_shares        = optional(number, 256)
  }))
  default = []
  validation {
    condition     = alltrue([for app in var.wordpress_apps : can(regex("^[a-z0-9][a-z0-9-]*$", app.name))])
    error_message = "Each wordpress_apps entry name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
  validation {
    condition     = alltrue([for app in var.wordpress_apps : can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", app.domain))])
    error_message = "Each wordpress_apps entry domain must be a valid fully-qualified domain name."
  }
}

# =============================================================================
# NEXTCLOUD INSTANCES
# =============================================================================
# Add new Nextcloud instances by appending objects to nextcloud_apps in terraform.tfvars.

variable "nextcloud_name_prefix" {
  description = "Short prefix used in container, volume and network names for Nextcloud apps (e.g. nc)"
  type        = string
  default     = "nc"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.nextcloud_name_prefix))
    error_message = "nextcloud_name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "nextcloud_images" {
  description = "Docker images for the Nextcloud stack. Override individual keys to pin versions."
  type = object({
    nextcloud = optional(string, "nextcloud:28-apache")
    db        = optional(string, "postgres:15-alpine")
    redis     = optional(string, "redis:7-alpine")
  })
  default = {}
}

variable "nextcloud_db_name" {
  description = "PostgreSQL database name for Nextcloud"
  type        = string
  default     = "nextcloud"
}

variable "nextcloud_db_user" {
  description = "PostgreSQL database user for Nextcloud"
  type        = string
  default     = "nextcloud"
}

variable "nextcloud_db_host" {
  description = "Hostname of the PostgreSQL service within the Nextcloud internal network"
  type        = string
  default     = "db"
}

variable "nextcloud_redis_host" {
  description = "Hostname of the Redis service within the Nextcloud internal network"
  type        = string
  default     = "redis"
}

variable "nextcloud_redis_port" {
  description = "Port the Redis service listens on"
  type        = number
  default     = 6379
}

variable "nextcloud_trusted_proxies" {
  description = "CIDR range of trusted reverse proxies passed to Nextcloud (TRUSTED_PROXIES)"
  type        = string
  default     = "172.16.0.0/12"
}

variable "nextcloud_apps" {
  description = <<-EOD
    List of Nextcloud instance definitions.
    Required fields : name, domain
    Optional fields : admin_user, php_memory_limit, max_upload_size,
                      redis_maxmemory, redis_maxmemory_policy
  EOD
  type = list(object({
    name                   = string
    domain                 = string
    admin_user             = optional(string, "admin")
    www_redirect           = optional(bool, false)
    php_memory_limit       = optional(string, "1024M")
    max_upload_size        = optional(string, "2G")
    redis_maxmemory        = optional(string, "256mb")
    redis_maxmemory_policy = optional(string, "allkeys-lru")
    app_memory_limit       = optional(number, 1024)
    app_cpu_shares         = optional(number, 1024)
    cron_memory_limit      = optional(number, 256)
    cron_cpu_shares        = optional(number, 256)
    db_memory_limit        = optional(number, 512)
    db_cpu_shares          = optional(number, 512)
    redis_memory_limit     = optional(number, 512)
    redis_cpu_shares       = optional(number, 256)
  }))
  default = []
  validation {
    condition     = alltrue([for app in var.nextcloud_apps : can(regex("^[a-z0-9][a-z0-9-]*$", app.name))])
    error_message = "Each nextcloud_apps entry name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
  validation {
    condition     = alltrue([for app in var.nextcloud_apps : can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", app.domain))])
    error_message = "Each nextcloud_apps entry domain must be a valid fully-qualified domain name."
  }
}

# =============================================================================
# ADVANCED SETTINGS
# =============================================================================
# These control how Traefik connects to the Docker daemon.
# Change only if running Docker in a non-standard configuration.

variable "traefik_docker_socket" {
  description = "Path to the Docker socket on the host (mounted read-only into Traefik)"
  type        = string
  default     = "/var/run/docker.sock"
}

variable "traefik_docker_api_version" {
  description = "Docker API version negotiated between Traefik and the daemon"
  type        = string
  default     = "1.45"
}
