# =============================================================================
# WordPress apps module variables
# =============================================================================
#
# REQUIRED   — must be supplied by the caller (no default)
# APP CONFIG — per-instance tuning with sensible defaults
# INFRA      — shared deployment settings (restart, security, Traefik)
# ADVANCED   — internal paths, healthchecks, runtime constants
#              Change only if your Docker images use non-standard layouts
#
# =============================================================================

# =============================================================================
# REQUIRED
# =============================================================================

variable "name" {
  description = "Unique short name for this WordPress site (used in resource names)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name))
    error_message = "name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "domain" {
  description = "Public FQDN for this WordPress site (e.g. blog.example.com)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain))
    error_message = "domain must be a valid fully-qualified domain name."
  }
}

variable "db_name" {
  description = "MariaDB database name for this site"
  type        = string
}

variable "db_user" {
  description = "MariaDB database username for this site"
  type        = string
}

# =============================================================================
# APP CONFIG
# =============================================================================

variable "table_prefix" {
  description = "WordPress database table prefix"
  type        = string
  default     = "wp_"
}

variable "www_redirect" {
  description = "Route both www.domain and domain to this site (adds www to Traefik host rule)"
  type        = bool
  default     = false
}

variable "php_memory_limit" {
  description = "WordPress PHP memory limit (WP_MEMORY_LIMIT)"
  type        = string
  default     = "512M"
}

variable "php_upload_max_filesize" {
  description = "PHP maximum upload file size"
  type        = string
  default     = "64M"
}

variable "php_post_max_size" {
  description = "PHP maximum POST data size"
  type        = string
  default     = "64M"
}

variable "php_max_execution_time" {
  description = "PHP maximum execution time in seconds"
  type        = number
  default     = 300
}

variable "redis_maxmemory" {
  description = "Redis maximum memory allocation"
  type        = string
  default     = "128mb"
}

variable "redis_maxmemory_policy" {
  description = "Redis memory eviction policy"
  type        = string
  default     = "allkeys-lru"
}

variable "wp_disallow_file_edit" {
  description = "Set DISALLOW_FILE_EDIT in wp-config.php (disable theme/plugin editor)"
  type        = bool
  default     = true
}

variable "wp_force_ssl_admin" {
  description = "Set FORCE_SSL_ADMIN in wp-config.php"
  type        = bool
  default     = true
}

variable "wp_auto_update_core" {
  description = "Set WP_AUTO_UPDATE_CORE in wp-config.php (minor | major | false)"
  type        = string
  default     = "minor"
}

variable "wp_cache" {
  description = "Set WP_CACHE in wp-config.php (enables object cache)"
  type        = bool
  default     = true
}

variable "app_memory_limit" {
  description = "Memory limit for the WordPress (PHP-FPM) container in MiB (0 = unlimited)"
  type        = number
  default     = 512
}

variable "app_cpu_shares" {
  description = "CPU shares for the WordPress (PHP-FPM) container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 1024
}

variable "nginx_memory_limit" {
  description = "Memory limit for the Nginx sidecar container in MiB (0 = unlimited)"
  type        = number
  default     = 128
}

variable "nginx_cpu_shares" {
  description = "CPU shares for the Nginx sidecar container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 256
}

variable "db_memory_limit" {
  description = "Memory limit for the MariaDB container in MiB (0 = unlimited)"
  type        = number
  default     = 512
}

variable "db_cpu_shares" {
  description = "CPU shares for the MariaDB container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 512
}

variable "redis_memory_limit" {
  description = "Memory limit for the Redis container in MiB (0 = unlimited). Should be >= redis_maxmemory."
  type        = number
  default     = 256
}

variable "redis_cpu_shares" {
  description = "CPU shares for the Redis container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 256
}

variable "wpcli_memory_limit" {
  description = "Memory limit for the WP-CLI sidecar container in MiB (0 = unlimited)"
  type        = number
  default     = 128
}

variable "wpcli_cpu_shares" {
  description = "CPU shares for the WP-CLI container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 256
}


# =============================================================================
# INFRA
# =============================================================================

variable "base_app_dir" {
  description = "Root directory on the host for application data (e.g. /opt)"
  type        = string
}

variable "traefik_network" {
  description = "Name of the shared Traefik Docker network"
  type        = string
}

variable "remote_host" {
  description = "SSH target for provisioners, format: user@host (empty = local)"
  type        = string
  default     = ""
}


variable "name_prefix" {
  description = "Short prefix for all resource names created by this module (e.g. wp)"
  type        = string
  default     = "wp"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "wordpress_image" {
  description = "WordPress Docker image (PHP-FPM variant)"
  type        = string
  default     = "wordpress:6-fpm-alpine"
}

variable "wordpress_db_image" {
  description = "MariaDB Docker image for WordPress"
  type        = string
  default     = "mariadb:10.11"
}

variable "wordpress_redis_image" {
  description = "Redis Docker image for WordPress object cache"
  type        = string
  default     = "redis:7-alpine"
}

variable "wordpress_nginx_image" {
  description = "Nginx Docker image (front-end proxy for PHP-FPM)"
  type        = string
  default     = "nginx:alpine"
}

variable "wordpress_cli_image" {
  description = "WP-CLI Docker image (management sidecar)"
  type        = string
  default     = "wordpress:cli"
}

variable "restart_policy" {
  description = "Docker restart policy for all containers in this module"
  type        = string
  default     = "unless-stopped"
  validation {
    condition     = contains(["unless-stopped", "always", "on-failure", "no"], var.restart_policy)
    error_message = "restart_policy must be one of: no, always, on-failure, unless-stopped."
  }
}

variable "security_opts" {
  description = "Docker security options for all containers in this module"
  type        = list(string)
  default     = ["no-new-privileges:true"]
}

variable "db_host" {
  description = "Hostname of the MariaDB container on the internal network"
  type        = string
  default     = "db"
}

variable "db_port" {
  description = "Port the MariaDB service listens on"
  type        = number
  default     = 3306
}

variable "redis_host" {
  description = "Hostname of the Redis container on the internal network"
  type        = string
  default     = "redis"
}

variable "redis_port" {
  description = "Port the Redis service listens on"
  type        = number
  default     = 6379
}

variable "redis_db" {
  description = "Redis database index used by WordPress"
  type        = number
  default     = 0
}

# Traefik label values

variable "traefik_enabled" {
  description = "Value for the traefik.enable container label"
  type        = string
  default     = "true"
}

variable "traefik_tls" {
  description = "Value for the traefik.http.routers.*.tls label"
  type        = string
  default     = "true"
}

variable "traefik_entrypoint" {
  description = "Traefik entrypoint name for HTTPS routing"
  type        = string
  default     = "websecure"
}

variable "traefik_cert_resolver" {
  description = "Traefik TLS certificate resolver name"
  type        = string
  default     = "letsencrypt"
}

variable "traefik_middlewares" {
  description = "Comma-separated Traefik middlewares applied to this app's router"
  type        = string
  default     = "security-headers@file,rate-limit@file,compress@file"
}

variable "container_port" {
  description = "Port the Nginx front-end container listens on (used in Traefik load balancer label)"
  type        = number
  default     = 80
}

# =============================================================================
# ADVANCED
# =============================================================================

variable "db_data_path" {
  description = "MariaDB data directory inside the container"
  type        = string
  default     = "/var/lib/mysql"
}

variable "db_charset" {
  description = "MariaDB character set"
  type        = string
  default     = "utf8mb4"
}

variable "db_collation" {
  description = "MariaDB collation"
  type        = string
  default     = "utf8mb4_unicode_ci"
}

variable "db_max_connections" {
  description = "MariaDB maximum concurrent connections"
  type        = number
  default     = 100
}

variable "redis_data_path" {
  description = "Redis data directory inside the container"
  type        = string
  default     = "/data"
}

variable "wordpress_data_path" {
  description = "WordPress files directory inside the container"
  type        = string
  default     = "/var/www/html"
}

variable "php_ini_path" {
  description = "Path for the PHP uploads ini file inside the WordPress container"
  type        = string
  default     = "/usr/local/etc/php/conf.d/uploads.ini"
}

variable "nginx_conf_path" {
  description = "Path to the Nginx configuration file inside the Nginx container"
  type        = string
  default     = "/etc/nginx/nginx.conf"
}

variable "wpcli_entrypoint" {
  description = "Entrypoint for the WP-CLI sidecar (keeps container alive for exec)"
  type        = list(string)
  default     = ["tail", "-f", "/dev/null"]
}

variable "db_healthcheck_test" {
  description = "Healthcheck test command for the MariaDB container"
  type        = list(string)
  default     = ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
}


variable "app_healthcheck_test" {
  description = "Healthcheck test command for the WordPress PHP-FPM container"
  type        = list(string)
  default     = ["CMD-SHELL", "pgrep php-fpm > /dev/null"]
}

variable "nginx_healthcheck_test" {
  description = "Healthcheck test command for the Nginx front-end container"
  type        = list(string)
  default     = ["CMD", "wget", "-q", "--spider", "http://127.0.0.1/nginx-health"]
}

variable "wpcli_healthcheck_test" {
  description = "Healthcheck test command for the WP-CLI container"
  type        = list(string)
  default     = ["CMD-SHELL", "wp --info > /dev/null 2>&1 || exit 1"]
}

variable "healthcheck_interval" {
  description = "Healthcheck interval for all containers"
  type        = string
  default     = "30s"
}

variable "healthcheck_timeout" {
  description = "Healthcheck timeout for all containers"
  type        = string
  default     = "5s"
}

variable "healthcheck_retries" {
  description = "Healthcheck retry count before marking a container unhealthy"
  type        = number
  default     = 3
}

variable "healthcheck_start_period" {
  description = "Healthcheck grace period for Redis, Nginx, and WP-CLI containers"
  type        = string
  default     = "10s"
}

variable "db_healthcheck_retries" {
  description = "Healthcheck retry count for the database container (needs longer)"
  type        = number
  default     = 5
}

variable "db_healthcheck_start_period" {
  description = "Healthcheck grace period for the database container"
  type        = string
  default     = "30s"
}

variable "app_healthcheck_start_period" {
  description = "Healthcheck grace period for the WordPress PHP-FPM container"
  type        = string
  default     = "30s"
}

variable "wpcli_healthcheck_interval" {
  description = "Healthcheck interval for the WP-CLI container (can be slow)"
  type        = string
  default     = "1m0s"
}

variable "wpcli_healthcheck_timeout" {
  description = "Healthcheck timeout for the WP-CLI container"
  type        = string
  default     = "10s"
}

variable "wpcli_healthcheck_start_period" {
  description = "Healthcheck grace period for the WP-CLI container"
  type        = string
  default     = "30s"
}
