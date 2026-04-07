# =============================================================================
# Nginx apps module variables
# =============================================================================
#
# REQUIRED   — must be supplied by the caller (no default)
# APP CONFIG — per-instance tuning with sensible defaults
# INFRA      — shared deployment settings (restart, security, Traefik)
# ADVANCED   — internal paths, healthchecks, runtime constants
#              Change only if your Docker image uses a non-standard layout
#
# =============================================================================

# =============================================================================
# REQUIRED
# =============================================================================

variable "name" {
  description = "Unique short name for this site (used in resource names)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name))
    error_message = "name must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "domain" {
  description = "Public FQDN for this site (e.g. example.com)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]*\\.[a-z]{2,}$", var.domain))
    error_message = "domain must be a valid fully-qualified domain name."
  }
}

variable "title" {
  description = "Page title shown on the default index page"
  type        = string
}

variable "message" {
  description = "Body message shown on the default index page"
  type        = string
}

# =============================================================================
# APP CONFIG
# =============================================================================

variable "www_redirect" {
  description = "Route both www.domain and domain to this site (adds www to Traefik host rule)"
  type        = bool
  default     = false
}

variable "custom_nginx_conf" {
  description = "Use a custom nginx.conf from the app directory instead of the generated default"
  type        = bool
  default     = false
}

variable "memory_limit" {
  description = "Memory limit for the Nginx container in MiB (0 = unlimited)"
  type        = number
  default     = 64
}

variable "cpu_shares" {
  description = "CPU shares for the Nginx container (relative weight; 1024 ≈ 1 CPU under contention)"
  type        = number
  default     = 512
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
  description = "Short prefix for all resource names created by this module (e.g. nx)"
  type        = string
  default     = "nx"
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, digits, and hyphens, and must start with a letter or digit."
  }
}

variable "nginx_image" {
  description = "Nginx Docker image"
  type        = string
  default     = "nginx:alpine"
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
  description = "Port the Nginx container listens on (used in Traefik load balancer label)"
  type        = number
  default     = 80
}

# =============================================================================
# ADVANCED
# =============================================================================

variable "webroot_path" {
  description = "Web root directory inside the container"
  type        = string
  default     = "/var/www/html"
}

variable "nginx_conf_path" {
  description = "Path to the active Nginx site config file inside the container"
  type        = string
  default     = "/etc/nginx/conf.d/default.conf"
}

variable "localtime_path" {
  description = "Path to localtime on host and inside container (bind-mounted read-only)"
  type        = string
  default     = "/etc/localtime"
}

variable "healthcheck_test" {
  description = "Healthcheck test command for the Nginx container"
  type        = list(string)
  default     = ["CMD", "wget", "-q", "--spider", "http://127.0.0.1/nginx-health"]
}

variable "healthcheck_interval" {
  description = "Healthcheck interval"
  type        = string
  default     = "30s"
}

variable "healthcheck_timeout" {
  description = "Healthcheck timeout"
  type        = string
  default     = "5s"
}

variable "healthcheck_retries" {
  description = "Healthcheck retry count before marking a container unhealthy"
  type        = number
  default     = 3
}

variable "healthcheck_start_period" {
  description = "Healthcheck grace period before retries count"
  type        = string
  default     = "10s"
}
