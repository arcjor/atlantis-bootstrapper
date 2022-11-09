data "azurerm_subscription" "current" {
}

resource "azurerm_storage_account" "atlantis_operational_storage" {
  name                     = var.atlantis_operational_storage_name
  resource_group_name      = var.atlantis_deployment_group_name
  location                 = var.atlantis_deployment_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_storage_container" "atlantis_operational_storage" {
  name                  = azurerm_storage_account.atlantis_operational_storage.name
  storage_account_name  = azurerm_storage_account.atlantis_operational_storage.name
  container_access_type = "private"
}

data "azurerm_key_vault" "atlantis_secrets_vault" {

  name                = var.atlantis_secrets_vault_name
  resource_group_name = var.atlantis_deployment_group_name
}

data "azurerm_key_vault_secret" "atlantis_gh_app_key_b64_secret" {

  count = var.runtime_mode == "run-app" ? 1 : 0

  name         = var.gh_app_key_b64_secret_name
  key_vault_id = data.azurerm_key_vault.atlantis_secrets_vault.id
}

data "azurerm_key_vault_secret" "atlantis_gh_webhook_secret" {

  count = var.runtime_mode != "create-app" ? 1 : 0
  
  name         = var.gh_webhook_secret_name
  key_vault_id = data.azurerm_key_vault.atlantis_secrets_vault.id
}

data "azurerm_key_vault_secret" "gh_pat_secret" {

  count = var.gh_pat_secret_name != "" ? 1 : 0

  name         = var.gh_pat_secret_name
  key_vault_id = data.azurerm_key_vault.atlantis_secrets_vault.id
}

resource "azurerm_container_group" "atlantis_runtime" {

  count = var.runtime_mode != "create-app" ? 1 : 0

  name                = var.atlantis_deployment_group_name
  location            = var.atlantis_deployment_location
  resource_group_name = var.atlantis_deployment_group_name
  ip_address_type     = "Public"
  os_type             = "Linux"
  dns_name_label      = var.atlantis_dns_label

  container {
    name   = var.atlantis_container_name
    image  = var.atlantis_image
    cpu    = "1"
    memory = "2"

    ports {
        port     = var.atlantis_container_port
        protocol = "TCP"
      }

    environment_variables = {
      ARM_USE_MSI                     = "true"
      ARM_SKIP_CREDENTIALS_VALIDATION = "$SKIP_CREDENTIALS_VALIDATION"
      ARM_SKIP_PROVIDER_REGISTRATION  = "$SKIP_PROVIDER_REGISTRATION"
      ARM_ACCESS_KEY                  = "$STORAGE_KEY"
      ARM_SUBSCRIPTION_ID             = "$SUB_ID"
    }

    secure_environment_variables = {
      GITHUB_USER                = var.gh_username
      GITHUB_PAT                 = var.gh_pat_secret_name != "" ? data.azurerm_key_vault_secret.gh_pat_secret[0].value : "fake"
      ATLANTIS_GH_WEBHOOK_SECRET = data.azurerm_key_vault_secret.atlantis_gh_webhook_secret[0].value
    }

    # The command set will be unique depending on whether we are running as a GH user or a GH org app
    commands = var.runtime_mode == "run-app" ? [
      "atlantis",
      "server",
      "--gh-app-id",
      var.gh_app_id,
      "--gh-app-key-file",
      "/mnt/github-app-key/gh-app-key-file",
      "--repo-allowlist",
      var.gh_repo_allowlist,
      "--atlantis-url",
      "https://${var.atlantis_dns_label}.${var.atlantis_deployment_location}.azurecontainer.io:${var.atlantis_container_port}",
      "--write-git-creds",
      "--ssl-cert-file",
      "/mnt/atlantis-certs/atlantis.crt",
      "--ssl-key-file",
      "/mnt/atlantis-certs/atlantis.key"
    ]:[
      "atlantis",
      "server",
      "--gh-user",
      "$GITHUB_USER",
      "--gh-token",
      "$GITHUB_PAT",
      "--repo-allowlist",
      var.gh_repo_allowlist,
      "--atlantis-url",
      "https://${var.atlantis_dns_label}.${var.atlantis_deployment_location}.azurecontainer.io:${var.atlantis_container_port}",
      "--ssl-cert-file",
      "/mnt/atlantis-certs/atlantis.crt",
      "--ssl-key-file",
      "/mnt/atlantis-certs/atlantis.key"
    ]

    volume {
      name       = "atlantis-certs"
      mount_path = "/mnt/atlantis-certs"
      secret     = {
        "atlantis.crt" = data.azurerm_key_vault_secret.atlantis_tls_cert_b64_secret.value,
        "atlantis.key" = data.azurerm_key_vault_secret.atlantis_tls_key_b64_secret.value
      }
    }

    volume {
      name       = "github-app-key"
      mount_path = "/mnt/github-app-key"
      secret     = {
        "gh-app-key-file" = var.runtime_mode == "run-app" ? data.azurerm_key_vault_secret.atlantis_gh_app_key_b64_secret[0].value : base64encode("fake")
      }
    }
  }

  tags = {
    environment = "testing"
  }

  identity {
    type = "SystemAssigned"
  }

  timeouts {
    create = "5m"
  }
}

resource "azurerm_role_assignment" "atlantis_build_privileges" {

  count = var.runtime_mode != "create-app" ? 1 : 0

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = one(azurerm_container_group.atlantis_runtime[0].identity[*]).principal_id
}

resource "azurerm_container_group" "atlantis_create_github_app" {

  count = var.runtime_mode != "create-app" ? 0 : 1

  name                = var.atlantis_deployment_group_name
  location            = var.atlantis_deployment_location
  resource_group_name = var.atlantis_deployment_group_name
  ip_address_type     = "Public"
  os_type             = "Linux"
  dns_name_label      = var.atlantis_dns_label
 
  container {
    name   = var.atlantis_container_name
    image  = var.atlantis_image
    cpu    = "1"
    memory = "2"

    ports {
        port     = var.atlantis_container_port
        protocol = "TCP"
      }

    environment_variables = {
      ARM_USE_MSI                     = "true"
      ARM_SKIP_CREDENTIALS_VALIDATION = "$SKIP_CREDENTIALS_VALIDATION"
      ARM_SKIP_PROVIDER_REGISTRATION  = "$SKIP_PROVIDER_REGISTRATION"
      ARM_ACCESS_KEY                  = "$STORAGE_KEY"
      ARM_SUBSCRIPTION_ID             = "$SUB_ID"
    }

    secure_environment_variables = {
      GITHUB_USER = "arcjor"
    }

    commands = [
      "atlantis",
      "server",
      "--gh-user",
      "fake",
      "--gh-token",
      "fake",
      "--gh-org",
      var.gh_org_for_app_creation,
      "--atlantis-url",
      "https://${var.atlantis_dns_label}.${var.atlantis_deployment_location}.azurecontainer.io:${var.atlantis_container_port}",
      "--repo-allowlist",
      var.gh_repo_allowlist,
      "--ssl-cert-file",
      "/mnt/atlantis-certs/atlantis.crt",
      "--ssl-key-file",
      "/mnt/atlantis-certs/atlantis.key"
    ]

    volume {
      name       = "atlantis-certs"
      mount_path = "/mnt/atlantis-certs"
      secret     = {
        "atlantis.crt" = data.azurerm_key_vault_secret.atlantis_tls_cert_b64_secret.value,
        "atlantis.key" = data.azurerm_key_vault_secret.atlantis_tls_key_b64_secret.value
      }
    }
  }

  tags = {
    environment = "testing"
  }

  identity {
    type = "SystemAssigned"
  }

  timeouts {
    create = "5m"
  }
}
