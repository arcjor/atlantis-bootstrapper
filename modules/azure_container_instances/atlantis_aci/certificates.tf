
resource "tls_private_key" "tls_key" {

  count = var.tls_cert_b64_secret_name == "" ? 1 : 0

  algorithm = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "tls_cert" {

  count = var.tls_cert_b64_secret_name == "" ? 1 : 0
  
  private_key_pem = tls_private_key.tls_key[0].private_key_pem

  # Certificate expires after 1 year (8766 hours).
  validity_period_hours = 8766

  # Reasonable set of uses for a server SSL certificate.
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]

  dns_names = ["${var.atlantis_dns_label}.${var.atlantis_deployment_location}.azurecontainer.io"]

  subject {
    common_name  = "${var.atlantis_dns_label}.${var.atlantis_deployment_location}.azurecontainer.io"
    organization = "Dis"
  }
}

resource "azurerm_key_vault_secret" "atlantis_tls_cert_b64_secret_input" {

  count = var.tls_cert_b64_secret_name == "" ? 1 : 0

  name            = "self-signed-tls-cert-b64"
  value           = base64encode(tls_self_signed_cert.tls_cert[0].cert_pem)
  key_vault_id    = data.azurerm_key_vault.atlantis_secrets_vault.id
  content_type    = "tls"
  expiration_date = "2111-12-31T00:00:00Z"
}

resource "azurerm_key_vault_secret" "atlantis_tls_key_b64_secret_input" {

  count = var.tls_cert_b64_secret_name == "" ? 1 : 0

  name            = "self-signed-tls-key-b64"
  value           = base64encode(tls_private_key.tls_key[0].private_key_pem)
  key_vault_id    = data.azurerm_key_vault.atlantis_secrets_vault.id
  content_type    = "tls"
  expiration_date = "2111-12-31T00:00:00Z"
}

data "azurerm_key_vault_secret" "atlantis_tls_cert_b64_secret" {

  name         = var.tls_cert_b64_secret_name == "" ? azurerm_key_vault_secret.atlantis_tls_cert_b64_secret_input[0].name : var.tls_cert_b64_secret_name
  key_vault_id = data.azurerm_key_vault.atlantis_secrets_vault.id
}

data "azurerm_key_vault_secret" "atlantis_tls_key_b64_secret" {

  name         = var.tls_key_b64_secret_name == "" ? azurerm_key_vault_secret.atlantis_tls_key_b64_secret_input[0].name : var.tls_key_b64_secret_name
  key_vault_id = data.azurerm_key_vault.atlantis_secrets_vault.id
}