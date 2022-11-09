variable "atlantis_deployment_group_name" {
    description = "The resource group where atlantis will be deployed."
    type        = string
}

variable "atlantis_operational_storage_name" {
    description = "The storage account and container where atlantis will keep operational data (to store plans before apply)."
    type        = string
}

variable "atlantis_dns_label" {
    description = "The DNS label for the container. Hostname will take the form https://<dns-label>.<deployment-location>.azurecontainer.io:<port>"
    type        = string
}

variable "atlantis_secrets_vault_name" {
    description = "The name of the vault where atlantis secrets are stored."
    type        = string
}

variable "gh_webhook_secret_name" {
    description = "The name of the secret where a GH webhook secret is stored."
    type        = string
}

variable "gh_repo_allowlist" {
    description = "A comma separated list of git repos to allow webhooks from."
    type        = string
}

variable "atlantis_deployment_location" {
    description = "The location where the atlantis runtime will be deployed."
    type        = string
    default     = "eastus"
}

variable "atlantis_container_name" {
    description = "The name of the container in the container group."
    type        = string
    default     = "atlantis"
}

variable "atlantis_container_port" {
    description = "The port exposed by the atlantis container."
    type        = number
    default     = 4141
}

variable "atlantis_image" {
    description = "The container image used for the atlantis runtime."
    type        = string
    default     = "ghcr.io/runatlantis/atlantis:v0.20.0"
}

variable "runtime_mode" {
  description = "Runtime mode must be (create-app|run-user|run-app)"
  type        = string
  default     = "run-user"
}

variable "gh_pat_secret_name" {
    description = "The name of the secret where a GH personal access token is stored, empty string if none."
    type        = string
    default     = ""
}

variable "gh_app_key_b64_secret_name" {
    description = "The name of the secret where a GH app key is stored, empty string if none."
    type        = string
    default     = ""
}

variable "gh_app_id" {
    description = "The name of the GH App ID, empty string if none."
    type        = string
    default     = ""
}

variable "gh_username" {
    description = "The name of the GH User, empty string if none."
    type        = string
    default     = ""
}

variable "gh_org_for_app_creation" {
    description = "The name of the GH organization where an app should be created, empty string if none."
    type        = string
    default     = ""
}

variable "tls_cert_b64_secret_name" {
    description = "The name of the secret where a TLS certificate is stored, empty string if none."
    type        = string
    default     = ""
}

variable "tls_key_b64_secret_name" {
    description = "The name of the secret where a TLS key is stored, empty string if none."
    type        = string
    default     = ""
}
