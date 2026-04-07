# =============================================================================
# Deployment Outputs
# =============================================================================

output "nginx_urls" {
  description = "Nginx static site URLs"
  value       = { for k, v in module.nginx_apps : k => "https://${v.domain}" }
}

output "wordpress_urls" {
  description = "WordPress site URLs"
  value       = { for k, v in module.wordpress_apps : k => "https://${v.domain}" }
}

output "nextcloud_urls" {
  description = "Nextcloud instance URLs"
  value       = { for k, v in module.nextcloud_apps : k => "https://${v.domain}" }
}

output "nextcloud_credentials" {
  description = "Admin credentials for all Nextcloud instances"
  value       = { for k, v in module.nextcloud_apps : k => v.admin_credentials }
  sensitive   = true
}

output "get_nextcloud_credentials" {
  description = "How to retrieve Nextcloud admin credentials"
  value       = <<-EOT

    NEXTCLOUD CREDENTIALS
    =====================

    Retrieve the Nextcloud credentials after first run with:

    tofu output -json nextcloud_credentials | jq

  EOT

}
