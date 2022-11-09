#!/bin/bash

# This script templates the terraform modules into the live environment and collects all data necessary to complete the deployment.
# If this atlantis will be based on a github app then this script will trigger the initial deployment and allow the interactive creation.

if [ "$ATLANTIS_RUNNER_PATH" == "" ]; then
    echo "Error - Exiting. The bootstrap_terraform.sh script requires environment variable ATLANTIS_RUNNER_PATH to be set."
    exit 1
fi

collect_initial_user_data () {

    echo "Please enter necessary details for the new azure runner $SELECTED_ATLANTIS_RUNNER."

    while [ "$ATLANTIS_RUNNER_TFSTATE_KEY" == "" ]; do
        echo -e "The terraform state will be stored in the resource group and storage account specified in the environment.\nMultiple independent runners may be stored under unique TF state keys."
        read -p "Please enter a valid name to use for a terraform state key (such as terraform.tfstate): " ATLANTIS_RUNNER_TFSTATE_KEY
    done

    while [ "$ATLANTIS_RUNNER_DNS_LABEL" == "" ]; do
        read -p "Please enter a valid DNS label for the runner: " ATLANTIS_RUNNER_DNS_LABEL
    done

    while [ "$ATLANTIS_RUNNER_DEPLOYMENT_RG" == "" ]; do
        read -p "Please enter a valid resource group name for the runner: " ATLANTIS_RUNNER_DEPLOYMENT_RG
    done
    if [ $(az group exists --name $ATLANTIS_RUNNER_DEPLOYMENT_RG) = false ]; then
        az group create --name $ATLANTIS_RUNNER_DEPLOYMENT_RG --location "EastUS"
    fi

    while [ "$ATLANTIS_REPO_ALLOW_LIST" == "" ]; do
        read -p "Enter a comma separated list of repos Atlantis may operate on: " ATLANTIS_REPO_ALLOW_LIST
    done

    while [ "$ATLANTIS_SECRETS_VAULT_NAME" == "" ]; do
        read -p "Enter the name of a new keyvault where secrets for atlantis should be stored: " ATLANTIS_SECRETS_VAULT_NAME
    done
    
    az keyvault create --name "${ATLANTIS_SECRETS_VAULT_NAME}" --resource-group "${ATLANTIS_RUNNER_DEPLOYMENT_RG}" --location "EastUS"

    read -p "Base64 encode the contents of the TLS certificate and enter it, or press enter to use a self-signed cert: " ATLANTIS_TLS_CERT_B64
    if [ "$ATLANTIS_TLS_CERT_B64" != "" ]; then
        while [ "$ATLANTIS_TLS_CERT_B64_SECRET_NAME" == "" ]; do
            read -p "Enter the name of the secret to store the B64 TLS Cert content in: "  ATLANTIS_TLS_CERT_B64_SECRET_NAME
        done
        while [ "$ATLANTIS_TLS_KEY_B64" == "" ]; do
            read -s -p "Base64 encode the contents of the TLS key and enter it (value will not be echoed): " ATLANTIS_TLS_KEY_B64
            echo
        done
        while [ "$ATLANTIS_TLS_KEY_B64_SECRET_NAME" == "" ]; do
            read -p "Enter the name of the secret to store the B64 TLS Key content in: "  ATLANTIS_TLS_KEY_B64_SECRET_NAME
        done

        echo -e "\n\nTLS data has been collected. Injecting into vault.\n"

        az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_TLS_CERT_B64_SECRET_NAME}" --value "${ATLANTIS_TLS_CERT_B64}" > /dev/null
        az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_TLS_KEY_B64_SECRET_NAME}" --value "${ATLANTIS_TLS_KEY_B64}" > /dev/null
    fi

    while [ "$ATLANTIS_RUNNER_STORAGE_NAME" == "" ]; do
        read -p "Please enter a valid name to use for both the storage account and container for the runner: " ATLANTIS_RUNNER_STORAGE_NAME
    done

    while [ "$ATLANTIS_GIT_IDENTITY_TYPE" != "user" ] && [ "$ATLANTIS_GIT_IDENTITY_TYPE" != "org-app" ]; do
        read -p "Please enter the type of git identity ('user' or 'org-app'): " ATLANTIS_GIT_IDENTITY_TYPE
        export ATLANTIS_GIT_IDENTITY_TYPE
    done

    if [ "$ATLANTIS_GIT_IDENTITY_TYPE" == "user" ]; then

        # Gather details for a github user bootstrap -- these will be complete
        while [ "$ATLANTIS_GIT_USER" == "" ]; do
            read -p "Enter the name for your selected github user (as it appears in github): " ATLANTIS_GIT_USER
        done
        echo "Please generate a PAT for this user with repo scope."
        
        export ATLANTIS_GIT_WH_SECRET="$(echo $RANDOM | md5sum | head -c 20)"
        echo "Randomly generating a webhook secret for this identity: ${ATLANTIS_GIT_WH_SECRET}"
        while [ "$ATLANTIS_GH_WEBHOOK_SECRET_NAME" == "" ]; do
            read -p "Enter the name of the secret to store the webhook in: "  ATLANTIS_GH_WEBHOOK_SECRET_NAME
        done

        while [ "$ATLANTIS_GIT_PAT" == "" ]; do
            read -s -p "Enter the github personal access token for $ATLANTIS_GIT_USER (this will not be echoed and will be stored in a secret): " ATLANTIS_GIT_PAT
            echo
        done
        while [ "$ATLANTIS_GIT_PAT_SECRET_NAME" == "" ]; do
            read -p "Enter the name of the secret to store the Git personal access token in: "  ATLANTIS_GIT_PAT_SECRET_NAME
        done

        echo -e "\n\nTLS Secret has been collected. Injecting into vault.\n"

        az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_GIT_PAT_SECRET_NAME}" --value "${ATLANTIS_GIT_PAT}" > /dev/null
        az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_GH_WEBHOOK_SECRET_NAME}" --value "${ATLANTIS_GIT_WH_SECRET}" > /dev/null

        export ATLANTIS_GIT_ORG="fake"
        export ATLANTIS_GIT_ORG_APP_ID="fake"
        export ATLANTIS_GIT_ORG_APP_KEY="fake"

        export ATLANTIS_RUNTIME_MODE="run-user"
        
    else

        # Gather details for a github organization app bootstrap -- these will be partial until the runtime bootstraps the app
        read -p "Enter the name for the github org where your app will be created: " ATLANTIS_GIT_ORG
        export ATLANTIS_GIT_WH_SECRET="fake"
        export ATLANTIS_GIT_USER="fake"
        export ATLANTIS_GIT_PAT_SECRET_NAME=""
        export ATLANTIS_GIT_ORG_APP_ID="fake"
        export ATLANTIS_GIT_ORG_APP_KEY="fake"

        export ATLANTIS_RUNTIME_MODE="run-app"
    fi
}

render_initial_tf_content () {

    cat << EOF > "$ATLANTIS_RUNNER_PATH/main.tf"
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.28.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

module "atlantis_aci" {
    source = "/modules/azure_container_instances/atlantis_aci/"

    atlantis_deployment_group_name    = var.atlantis_deployment_group_name
    atlantis_operational_storage_name = var.atlantis_operational_storage_name
    atlantis_dns_label                = var.atlantis_dns_label
    atlantis_secrets_vault_name       = var.atlantis_secrets_vault_name
    gh_webhook_secret_name            = var.gh_webhook_secret_name
    gh_repo_allowlist                 = var.gh_repo_allowlist
    runtime_mode                      = var.runtime_mode
    gh_pat_secret_name                = var.gh_pat_secret_name
    gh_app_key_b64_secret_name        = var.gh_app_key_b64_secret_name
    gh_app_id                         = var.gh_app_id
    gh_username                       = var.gh_username
    gh_org_for_app_creation           = var.gh_org_for_app_creation
    tls_cert_b64_secret_name          = var.tls_cert_b64_secret_name
    tls_key_b64_secret_name           = var.tls_key_b64_secret_name
}
EOF

    cat << EOF > "$ATLANTIS_RUNNER_PATH/variables.tf"
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
EOF

    export ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP="$(cat $ATLANTIS_RUNNER_PATH/../environment.json | jq -r .'ATLANTIS_AZURE_ENV_RESOURCE_GROUP')"
    export ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT="$(cat $ATLANTIS_RUNNER_PATH/../environment.json | jq -r .'ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT')"
    export ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER="$(cat $ATLANTIS_RUNNER_PATH/../environment.json | jq -r .'ATLANTIS_AZURE_ENV_STORAGE_CONTAINER')"

    cat << EOF > "$ATLANTIS_RUNNER_PATH/backend.conf"
resource_group_name  = "$ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP"
storage_account_name = "$ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT"
container_name       = "$ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER"
key                  = "$ATLANTIS_RUNNER_TFSTATE_KEY"
EOF

    # Create an initial tfvars file which will be used for github app creation if applicable.
    # This file will be overwritten later.
    cat << EOF > "$ATLANTIS_RUNNER_PATH/terraform.tfvars"
gh_app_id = "fake"

atlantis_deployment_group_name = "${ATLANTIS_RUNNER_DEPLOYMENT_RG}"

atlantis_operational_storage_name = "${ATLANTIS_RUNNER_STORAGE_NAME}"

atlantis_secrets_vault_name = "${ATLANTIS_SECRETS_VAULT_NAME}"

tls_cert_b64_secret_name = "${ATLANTIS_TLS_CERT_B64_SECRET_NAME}"

tls_key_b64_secret_name = "${ATLANTIS_TLS_KEY_B64_SECRET_NAME}"

gh_webhook_secret_name = "fake"

gh_repo_allowlist = "fake"

runtime_mode = "create-app"

gh_pat_secret_name = ""

gh_app_key_b64_secret_name = "fake"

gh_username = "fake"

gh_org_for_app_creation = "${ATLANTIS_GIT_ORG}"

atlantis_dns_label = "${ATLANTIS_RUNNER_DNS_LABEL}"
EOF
}

create_github_app () {

    cd "$ATLANTIS_RUNNER_PATH"

    echo -e "\n\n\n\n\nThe script will now terraform apply the atlantis runtime in a preliminary state which will create the github app.\n\n\n\n\n"
    sleep 3

    terraform init -backend-config=backend.conf

    terraform apply

    cd -

    echo "Please follow the steps found at https://www.runatlantis.io/docs/access-credentials.html#github-app to create a github app and then enter the resulting data."
    echo "The setup page in the deployed atlantis container may be found at: https://${ATLANTIS_RUNNER_DNS_LABEL}.eastus.azurecontainer.io:4141/github-app/setup"
    read -p "Enter the app ID of the created github app: " ATLANTIS_GIT_APP_ID
    read -s -p "Base64 encode the contents of the gh-app-key-file and enter it (value will not be echoed): " ATLANTIS_GIT_APP_KEY_B64
    echo
    read -p "Enter the name of the secret to store the B64 App Key string in: " ATLANTIS_GH_APP_KEY_B64_SECRET_NAME
    read -s -p "Enter the literal value of the gh-webhook-secret (value will not be echoed): " ATLANTIS_GIT_APP_WEBHOOK_SECRET
    echo
    read -p "Enter the name of the secret to store the webhook string in: " ATLANTIS_GH_WEBHOOK_SECRET_NAME
    echo -e "\n\nSecrets have been collected. Injecting into vault.\n"

    az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_GH_WEBHOOK_SECRET_NAME}" --value "${ATLANTIS_GIT_APP_WEBHOOK_SECRET}" > /dev/null
    az keyvault secret set --vault-name "${ATLANTIS_SECRETS_VAULT_NAME}" --name "${ATLANTIS_GH_APP_KEY_B64_SECRET_NAME}" --value "${ATLANTIS_GIT_APP_KEY_B64}" > /dev/null

}

write_final_tfvars () {

    # Create a final tfvars file which will be used for bringing atlantis to steady-state runtime.
    cat << EOF > "$ATLANTIS_RUNNER_PATH/terraform.tfvars"
gh_app_id = "${ATLANTIS_GIT_APP_ID}"

atlantis_deployment_group_name = "${ATLANTIS_RUNNER_DEPLOYMENT_RG}"

atlantis_operational_storage_name = "${ATLANTIS_RUNNER_STORAGE_NAME}"

atlantis_secrets_vault_name = "${ATLANTIS_SECRETS_VAULT_NAME}"

tls_cert_b64_secret_name = "${ATLANTIS_TLS_CERT_B64_SECRET_NAME}"

tls_key_b64_secret_name = "${ATLANTIS_TLS_KEY_B64_SECRET_NAME}"

gh_webhook_secret_name = "${ATLANTIS_GH_WEBHOOK_SECRET_NAME}"

gh_repo_allowlist = "${ATLANTIS_REPO_ALLOW_LIST}"

runtime_mode = "${ATLANTIS_RUNTIME_MODE}"

gh_pat_secret_name = "${ATLANTIS_GIT_PAT_SECRET_NAME}"

gh_app_key_b64_secret_name = "${ATLANTIS_GH_APP_KEY_B64_SECRET_NAME}"

gh_username = "${ATLANTIS_GIT_USER}"

atlantis_dns_label = "${ATLANTIS_RUNNER_DNS_LABEL}"
EOF
}

collect_initial_user_data
render_initial_tf_content
if [ "$ATLANTIS_GIT_IDENTITY_TYPE" == "org-app" ]; then
    create_github_app
fi
write_final_tfvars
