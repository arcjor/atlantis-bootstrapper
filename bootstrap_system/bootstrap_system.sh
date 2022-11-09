# This script will sequentially descend through the organization heirarchy, allowing the user to bootstrap new environment/runner/repo 
# or to select a previously bootstrapped option.

# Resolve the path of the script being run
SCRIPT_ROOT_PATH="$( cd -- "$(dirname "$0")/.." >/dev/null 2>&1 ; pwd -P )"

if [ "$ATLANTIS_LIVE_REPO_PATH" == "" ]; then
    echo "Error - Exiting. The bootstrap_system.sh script requires environment variable ATLANTIS_LIVE_REPO_PATH to be set."
    exit 1
fi
if [ ! -d "$ATLANTIS_LIVE_REPO_PATH/live" ]; then
    echo "Error - Exiting. Expected to find directory named 'live' inside ATLANTIS_LIVE_REPO_PATH of $ATLANTIS_LIVE_REPO_PATH"
    exit 1
fi

select_environment () {

    SELECTED_ATLANTIS_ENVIRONMENT=""

    # Check if we have any environments bootstrapped yet
    environmentsubdircount=$(find $ATLANTIS_LIVE_REPO_PATH/live -maxdepth 1 -type d | wc -l)

    # Force bootstrapping of a new environment if none exist
    while [[ $environmentsubdircount -lt 2 ]]; do
        echo -e "No environments have been bootstrapped. Please enter a handle for a new environment to bootstrap.\nThis handle is unique to the atlantis-live repo and does not need to match any cloud resource."
        read -p "Enter a handle name for a new azure environment: " name
        echo "Creating azure environment $name"
        mkdir $ATLANTIS_LIVE_REPO_PATH/live/$name
        environmentsubdircount=$(find $ATLANTIS_LIVE_REPO_PATH/live -maxdepth 1 -type d | wc -l)
        export SELECTED_ATLANTIS_ENVIRONMENT="$name"
    done

    # Select an environment
    while [ ! -d "$ATLANTIS_LIVE_REPO_PATH/live/$SELECTED_ATLANTIS_ENVIRONMENT" ] || [ "$SELECTED_ATLANTIS_ENVIRONMENT" == "" ]; do
        echo "Please either enter an existing atlantis environment handle from the available selections or define a new one:"
        ls -d $ATLANTIS_LIVE_REPO_PATH/live/*/
        read -p "Enter the handle name for your selected azure environment: " name
        export SELECTED_ATLANTIS_ENVIRONMENT="$name"
        if [ ! -d "$ATLANTIS_LIVE_REPO_PATH/live/$SELECTED_ATLANTIS_ENVIRONMENT" ] && [ "$SELECTED_ATLANTIS_ENVIRONMENT" != "" ]; then
            echo "Creating azure environment $name"
            mkdir $ATLANTIS_LIVE_REPO_PATH/live/$name
        fi
    done

    export ATLANTIS_ENVIRONMENT_PATH="$ATLANTIS_LIVE_REPO_PATH/live/$SELECTED_ATLANTIS_ENVIRONMENT/"

    # If this environment is undefined then collect necessary data
    if [ ! -f "$ATLANTIS_ENVIRONMENT_PATH/environment.json" ]; then

        export CREATE_AZURE_ENVIRONMENT="true"

        echo "Please enter necessary details for the new azure environment $SELECTED_ATLANTIS_ENVIRONMENT."
        if [ "$ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID" == "" ]; then
            read -p "Please enter the subscription ID for the Azure Environment: " ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID
            export ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID
        fi
        if [ "$ATLANTIS_AZURE_ENV_RESOURCE_GROUP" == "" ]; then
            read -p "Please enter the resource group name for the Azure Environment: " ATLANTIS_AZURE_ENV_RESOURCE_GROUP
            export ATLANTIS_AZURE_ENV_RESOURCE_GROUP
        fi
        if [ "$ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT" == "" ]; then
            read -p "Please enter the storage account name for the Azure Environment: " ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT
            export ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT
        fi
        if [ "$ATLANTIS_AZURE_ENV_STORAGE_CONTAINER" == "" ]; then
            read -p "Please enter the storage container name for the Azure Environment: " ATLANTIS_AZURE_ENV_STORAGE_CONTAINER
            export ATLANTIS_AZURE_ENV_STORAGE_CONTAINER
        fi
        jq -n --arg ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID "$ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID" \
             --arg ATLANTIS_AZURE_ENV_RESOURCE_GROUP "$ATLANTIS_AZURE_ENV_RESOURCE_GROUP" \
             --arg ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT "$ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT" \
             --arg ATLANTIS_AZURE_ENV_STORAGE_CONTAINER "$ATLANTIS_AZURE_ENV_STORAGE_CONTAINER" \
             '{"ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID":$ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID, "ATLANTIS_AZURE_ENV_RESOURCE_GROUP":$ATLANTIS_AZURE_ENV_RESOURCE_GROUP, "ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT":$ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT, "ATLANTIS_AZURE_ENV_STORAGE_CONTAINER":$ATLANTIS_AZURE_ENV_STORAGE_CONTAINER}' \
             > $ATLANTIS_ENVIRONMENT_PATH/environment.json
    else
        echo "Using already defined Azure Environment: $SELECTED_ATLANTIS_ENVIRONMENT"
    fi

    # Report data which defines the environment
    echo "Azure environment $SELECTED_ATLANTIS_ENVIRONMENT is in subscription $(cat $ATLANTIS_ENVIRONMENT_PATH/environment.json | jq -r .'ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID')"
}

ensure_az_login_complete () {

    if [ "$AZ_LOGIN_COMPLETE" != "true" ]; then
        az login
        export AZ_LOGIN_COMPLETE="true"
    fi
}

create_environment_if_needed () {

    if [ "$CREATE_AZURE_ENVIRONMENT" == "true" ]; then
        echo "Creating new resources for Azure environment $SELECTED_ATLANTIS_ENVIRONMENT"
        export ATLANTIS_BOOTSTRAP_ENV_SUBSCRIPTION="$(cat $ATLANTIS_ENVIRONMENT_PATH/environment.json | jq -r .'ATLANTIS_AZURE_ENV_SUBSCRIPTION_ID')"
        export ATLANTIS_BOOTSTRAP_ENV_RESOURCE_GROUP="$(cat $ATLANTIS_ENVIRONMENT_PATH/environment.json | jq -r .'ATLANTIS_AZURE_ENV_RESOURCE_GROUP')"
        export ATLANTIS_BOOTSTRAP_ENV_STORAGE_ACCOUNT="$(cat $ATLANTIS_ENVIRONMENT_PATH/environment.json | jq -r .'ATLANTIS_AZURE_ENV_STORAGE_ACCOUNT')"
        export ATLANTIS_BOOTSTRAP_ENV_STORAGE_CONTIANER="$(cat $ATLANTIS_ENVIRONMENT_PATH/environment.json | jq -r .'ATLANTIS_AZURE_ENV_STORAGE_CONTAINER')"
        ensure_az_login_complete
        $SCRIPT_ROOT_PATH/bootstrap_azure_environment/bootstrap_azure_environment.sh
    fi
}

select_atlantis_runner () {

    SELECTED_ATLANTIS_RUNNER=""

    # Check if we have any git identities stored yet
    runnersubdircount=$(find $ATLANTIS_ENVIRONMENT_PATH -maxdepth 1 -type d | wc -l)

    # Force bootstrapping of a new atlantis runner if none exist
    while [[ $runnersubdircount -lt 2 ]]; do
        echo -e "No atlantis runners have been bootstrapped. Please enter a handle for a new atlantis runner to bootstrap.\nThis handle is unique to the atlantis-live repo and does not need to match external resources."
        read -p "Enter a handle name for a new atlantis runner: " name
        echo "Storing atlantis runner $name"
        mkdir $ATLANTIS_ENVIRONMENT_PATH/$name
        runnersubdircount=$(find $ATLANTIS_ENVIRONMENT_PATH -maxdepth 1 -type d | wc -l)
        export SELECTED_ATLANTIS_RUNNER="$name"
    done

    # Select an atlantis runner
    while [ ! -d "$ATLANTIS_ENVIRONMENT_PATH/$SELECTED_ATLANTIS_RUNNER" ] || [ "$SELECTED_ATLANTIS_RUNNER" == "" ]; do
        echo "Please either enter an existing atlantis runner handle from the available selections or define a new one:"
        ls -d $ATLANTIS_ENVIRONMENT_PATH/*/
        read -p "Enter the handle name for your selected atlantis runner: " name
        export SELECTED_ATLANTIS_RUNNER="$name"
        if [ ! -d "$ATLANTIS_ENVIRONMENT_PATH/$SELECTED_ATLANTIS_RUNNER" ] && [ "$SELECTED_ATLANTIS_RUNNER" != "" ]; then
            echo "Storing git identity $name"
            mkdir $ATLANTIS_ENVIRONMENT_PATH/$name
        fi
    done

    export ATLANTIS_RUNNER_PATH="$ATLANTIS_ENVIRONMENT_PATH/$SELECTED_ATLANTIS_RUNNER/"
}

create_atlantis_runner_if_needed () {

    # If this runner is undefined then collect data
    if [ ! -f "$ATLANTIS_RUNNER_PATH/main.tf" ]; then

        export CREATE_ATLANTIS_RUNNER="true"

        ensure_az_login_complete
        $SCRIPT_ROOT_PATH/bootstrap_azure_atlantis/bootstrap_terraform.sh
        
    else
        echo "Using already defined Azure Runner: $SELECTED_ATLANTIS_RUNNER"
    fi

}

apply_terraform_updates () {

    ensure_az_login_complete
    $SCRIPT_ROOT_PATH/bootstrap_azure_atlantis/apply_terraform_updates.sh
}

select_environment
create_environment_if_needed
select_atlantis_runner
create_atlantis_runner_if_needed
apply_terraform_updates
