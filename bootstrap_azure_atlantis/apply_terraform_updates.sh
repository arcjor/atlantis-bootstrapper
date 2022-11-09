#!/bin/bash

# This script applies the terraform updates for the atlantis runtime instance in runtime mode

if [ "$ATLANTIS_RUNNER_PATH" == "" ]; then
    echo "Error - Exiting. The apply_terraform_updates.sh script requires environment variable ATLANTIS_RUNNER_PATH to be set."
    exit 1
fi
if [ "$SELECTED_ATLANTIS_RUNNER" == "" ]; then
    echo "Error - Exiting. The apply_terraform_updates.sh script requires environment variable SELECTED_ATLANTIS_RUNNER to be set."
    exit 1
fi
if [ "$SELECTED_ATLANTIS_ENVIRONMENT" == "" ]; then
    echo "Error - Exiting. The apply_terraform_updates.sh script requires environment variable SELECTED_ATLANTIS_ENVIRONMENT to be set."
    exit 1
fi

cd "$ATLANTIS_RUNNER_PATH"

echo "Pre-apply actions are complete. Please review terraform configuration in <ATLANTIS_LIVE_PATH>/live/$SELECTED_ATLANTIS_ENVIRONMENT/$SELECTED_ATLANTIS_RUNNER"
read -p "Press enter when ready to terraform init and terraform apply." READY_TO_RUN

terraform init -backend-config=backend.conf

terraform apply
