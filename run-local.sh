#!/usr/bin/env bash

# Script to run the generation scripts locally with the local Docker engine
# Copy ./env-template.sh to ./env.sh and set desired configuration values.

# Docker registry was setup with a locally running Artifactory:
## $ docker run --name rt -p 8082:8082 releases-docker.jfrog.io/jfrog/artifactory-jcr

# Create a docker-local Docker repository:
## $ curl -u admin:password -X PUT http://localhost:8082/artifactory/api/repositories/docker-local \
#       -H 'Content-Type: application/json' \
#       -d '{"key": "docker-local", "rclass": "local", "packageType": "docker", "description": "Docker local repository"}'

[ "${DEBUG}" == true ] && set -x

errorExit() {
    echo "ERROR: $1"
    exit 1
}

terminate() {
    echo -e "\nTerminating..."
    exit 1
}

buildImagesLoop() {
    local num=$1
    for b in $(seq 1 "${num}"); do
        sleep 1
        ./run-docker-build-and-push.sh "${b}" &
    done

    # Wait for all background processes to finish
    wait
}

# Catch Ctrl+C and other termination signals to shutdown
trap terminate SIGINT SIGTERM SIGHUP

START_TIME=$(date +'%s')

# Load the configured environment variables
if [[ ! -f ./env.sh ]]; then
    echo
    echo "########################################################################"
    echo "# Creating initial env.sh from env-template.sh."
    echo "# Edit env.sh with the required configuration and run $0 again."
    echo "########################################################################"
    echo
    cp ./env-template.sh ./env.sh || errorExit "Copying ./env-template.sh to ./env.sh failed"
    exit 0
fi
source ./env.sh || errorExit "Loading env.sh failed"

# Set defaults if any param is missing
export NUMBER_OF_IMAGES=${NUMBER_OF_IMAGES:-1}
export NUMBER_OF_LAYERS=${NUMBER_OF_LAYERS:-1}
export SIZE_OF_LAYER_KB=${SIZE_OF_LAYER_KB:-1}
export NUM_OF_THREADS=${NUM_OF_THREADS:-1}
export DOCKER_REGISTRY=${DOCKER_REGISTRY?Must set DOCKER_REGISTRY}
export INSECURE_REGISTRY=${INSECURE_REGISTRY:-false}
export DOCKER_USER=${DOCKER_USER:-admin}
export DOCKER_PASSWORD=${DOCKER_PASSWORD:-password}
export REPO_PATH=${REPO_PATH:-docker-auto}
export REMOVE_IMAGES=${REMOVE_IMAGES:-true}
export TAG=${TAG:-1}

echo "== Creating ${NUMBER_OF_IMAGES} Docker images"
echo "== Images with ${NUMBER_OF_LAYERS} layers"
echo "== Layers size ${SIZE_OF_LAYER_KB} KB"
echo "== Using ${NUM_OF_THREADS} threads"
echo

# Login to registry
echo "Docker login to ${DOCKER_REGISTRY}"
docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY} || errorExit "Docker login failed. Do you have a running Docker registry?"

# Calculate the loop size
LOOP_SIZE=$((${NUMBER_OF_IMAGES} / ${NUM_OF_THREADS}))
LOOP_REMAINDER=$((${NUMBER_OF_IMAGES} % ${NUM_OF_THREADS}))

echo "LOOP_SIZE is ${LOOP_SIZE}"
echo "LOOP_REMAINDER is ${LOOP_REMAINDER}"

# Create the Docker images
if [ ${LOOP_SIZE} -gt 0 ]; then
    for a in $(seq 1 ${LOOP_SIZE}); do
        echo -e "\n[${a}/${LOOP_SIZE}] Preparing batch of ${NUM_OF_THREADS} images"
        buildImagesLoop ${NUM_OF_THREADS}
    done
fi

# Do the remainder threads if needed
if [ ${LOOP_REMAINDER} -gt 0 ]; then
    echo -e "\n[Remainder (last batch)] Preparing batch of ${LOOP_REMAINDER} images"
    buildImagesLoop ${LOOP_REMAINDER}
fi

END_TIME=$(date +'%s')
ELAPSED_TIME=$((${END_TIME} - ${START_TIME}))

echo "==============================================="
echo "== Completed in:          ${ELAPSED_TIME} seconds"
echo "== Created:               ${NUMBER_OF_IMAGES} images"
echo "== Each image with:       ${NUMBER_OF_LAYERS} layers"
echo "== Layer size:            ${SIZE_OF_LAYER_KB} KB"
echo "== Using:                 ${NUM_OF_THREADS} threads"
echo "==============================================="
