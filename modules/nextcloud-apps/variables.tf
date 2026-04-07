# =============================================================================
# Nextcloud Apps Module — Variables
# =============================================================================
#
# REQUIRED   — must be supplied by the caller (no default)
# APP CONFIG — per-instance tuning with sensible defaults
# INFRA      — shared deployment settings (restart, security, Traefik)
# ADVANCED   — internal paths, healthchecks, runtime constants
#              Change only if your Docker images use non-standard layouts.
#
# =============================================================================

# =============================================================================
# REQUIRED
# =============================================================================

variable "name" {
  description = "Unique short name for this Nextcloud instance (used in resource names)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name))
    error_message = "name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "domain" {
  description = "Public FQDN for this Nextcloud instance (e.g. cloud.example.com)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain))
    error_message = "domain must be a valid fully-qualified domain name."
  }
}

# =============================================================================
# APP CONFIG
# =============================================================================

variable "admin_user" {
  description = "Nextcloud admin username created on first boot"
  type        = string
  default     = "admin"
}

variable "www_redirect" {
  description = "Route both www.domain and domain to this site (adds www to Traefik host rule)"
  type        = bool
  default     = false
}

variable "php_memory_limit" {
  description = "PHP memory limit (NEXTCLOUD_PHP_MEMORY_LIMIT)"
  type        = string
  default     = "1024M"
}

variable "max_upload_size" {
  description = "Maximum file upload size (PHP_UPLOAD_LIMIT)"
  type        = string
  default     = "2G"
}

variable "redis_maxmemory" {
  description = "Redis maximum memory allocation"
  type        = string
  default     = "256mb"
}

variable "redis_maxmemory_policy" {
  description = "Redis memory eviction policy"
  type        = string
  default     = "allkeys-lru"
}

variable "app_memory_limit" {
  description = "Memory limit for the Nextcloud application container in MiB (0 = unlimited)"
  type        = number
  default     = 1024
}

variable "app_cpu_shares" {
  description = "CPU shares for the Nextcloud application container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 1024
}

variable "cron_memory_limit" {
  description = "Memory limit for the Nextcloud cron container in MiB (0 = unlimited)"
  type        = number
  default     = 256
}

variable "cron_cpu_shares" {
  description = "CPU shares for the Nextcloud cron container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 256
}

variable "db_memory_limit" {
  description = "Memory limit for the PostgreSQL container in MiB (0 = unlimited)"
  type        = number
  default     = 512
}

variable "db_cpu_shares" {
  description = "CPU shares for the PostgreSQL container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 512
}

variable "redis_memory_limit" {
  description = "Memory limit for the Redis container in MiB (0 = unlimited). Should be >= redis_maxmemory."
  type        = number
  default     = 512
}

variable "redis_cpu_shares" {
  description = "CPU shares for the Redis container (relative weight; 1024 ≈ 1 CPU under contention)"
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
  description = "Short prefix for all resource names created by this module (e.g. nc)"
  type        = string
  default     = "nc"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "nextcloud_image" {
  description = "Nextcloud Docker image"
  type        = string
  default     = "nextcloud:28-apache"
}

variable "nextcloud_db_image" {
  description = "PostgreSQL Docker image for Nextcloud"
  type        = string
  default     = "postgres:15-alpine"
}

variable "nextcloud_redis_image" {
  description = "Redis Docker image for Nextcloud"
  type        = string
  default     = "redis:7-alpine"
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

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "nextcloud"
}

variable "db_user" {
  description = "PostgreSQL database user"
  type        = string
  default     = "nextcloud"
}

variable "db_host" {
  description = "Hostname of the PostgreSQL container on the internal network"
  type        = string
  default     = "db"
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

variable "trusted_proxies" {
  description = "CIDR range of trusted reverse proxies (TRUSTED_PROXIES env var)"
  type        = string
  default     = "172.16.0.0/12"
}

variable "overwrite_protocol" {
  description = "Protocol reported to Nextcloud by the proxy (OVERWRITEPROTOCOL)"
  type        = string
  default     = "https"
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
  description = "Port the Nextcloud container listens on (used in Traefik load balancer label)"
  type        = number
  default     = 80
}

# =============================================================================
# ADVANCED
# =============================================================================

variable "db_data_path" {
  description = "PostgreSQL data directory inside the container"
  type        = string
  default     = "/var/lib/postgresql/data"
}

variable "redis_data_path" {
  description = "Redis data directory inside the container"
  type        = string
  default     = "/data"
}

variable "nextcloud_data_path" {
  description = "Nextcloud files directory inside the container"
  type        = string
  default     = "/var/www/html"
}

variable "cron_entrypoint" {
  description = "Entrypoint command for the Nextcloud cron container"
  type        = list(string)
  default     = ["/cron.sh"]
}


variable "app_healthcheck_test" {
  description = "Healthcheck test command for the Nextcloud app container"
  type        = list(string)
  default     = ["CMD", "curl", "-f", "http://localhost:80/status.php"]
}

variable "cron_healthcheck_test" {
  description = "Healthcheck test command for the Nextcloud cron container"
  type        = list(string)
  default     = ["CMD-SHELL", "pgrep -f 'crond' > /dev/null || exit 1"]
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
  description = "Healthcheck grace period for Redis and cron containers"
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

variable "app_healthcheck_timeout" {
  description = "Healthcheck timeout for the Nextcloud app container"
  type        = string
  default     = "10s"
}

variable "app_healthcheck_start_period" {
  description = "Healthcheck grace period for the Nextcloud app container"
  type        = string
  default     = "1m0s"
}
