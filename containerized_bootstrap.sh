#!/bin/bash

# Resolve the path of the script being run
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Find the latest tag from the repo to determine version
# export AGENT_TAG=$(git for-each-ref --sort=taggerdate --format '%(refname)' refs/tags | head -n 1)
export VERSION_TAG=v0.1.0

echo "Performing containerized Atlantis bootstrap from $SCRIPTPATH on repo version $VERSION_TAG"

# Define the live repo location if it is not defined. Assume the two repos are in the same workspace and atlantis-live has a default name.
if [ "$ATLANTIS_LIVE_REPO_PATH" == "" ]; then
    export ATLANTIS_LIVE_REPO_PATH="$(readlink -f ../atlantis-live)"
fi

# Basic sanity check to make sure atlantis-live is correctly specified
if [ ! -d "$ATLANTIS_LIVE_REPO_PATH/live" ]; then
    echo "Error - Exiting. Expected to find directory named 'live' inside ATLANTIS_LIVE_REPO_PATH of $ATLANTIS_LIVE_REPO_PATH"
    exit 1
fi

echo "Mounting atlantis-live repo from $ATLANTIS_LIVE_REPO_PATH"

cd "$SCRIPTPATH"
docker build -f bootstrapping_agent/Dockerfile -t atlantis-bootstrapper:"${VERSION_TAG}" .
cd -

docker run --rm -v $ATLANTIS_LIVE_REPO_PATH:/atlantis-live -it \
    -e ATLANTIS_LIVE_REPO_PATH="/atlantis-live/" \
    atlantis-bootstrapper:"${VERSION_TAG}" \
    ./bootstrap_system/bootstrap_system.sh
