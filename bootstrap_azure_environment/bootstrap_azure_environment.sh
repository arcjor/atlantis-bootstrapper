#!/bin/bash

if [ "$ATLANTIS_BOOTSTRAP_ENV_SUBSCRIPTION" == "" ]; then
    echo "ATLANTIS_BOOTSTRAP_ENV_SUBSCRIPTION variable not set."
    exit 1
fi

if [ "$ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP" == "" ]; then
    echo "ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP variable not set."
    exit 1
fi

if [ "$ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT" == "" ]; then
    echo "ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT variable not set."
    exit 1
fi

if [ "$ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER" == "" ]; then
    echo "ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER variable not set."
    exit 1
fi

SUBSCRIPTION_ID="$ATLANTIS_BOOTSTRAP_ENV_SUBSCRIPTION"
RESOURCE_GROUP_NAME="$ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP"
STORAGE_ACCOUNT_NAME="$ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT"
CONTAINER_NAME="$ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER"

# Ensure we are in the designated subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location eastus --tags creation-tool=atlantis-bootstrapper Env=dev

# Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME \
    --sku Standard_LRS --encryption-services blob --tags creation-tool=atlantis-bootstrapper Env=dev

# Create blob container
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME
