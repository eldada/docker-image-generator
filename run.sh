#!/bin/bash

[ "${DEBUG}" == true ] && set -x

terminate () {
    echo -e "\nTerminating..."
    exit 1
}

# Catch Ctrl+C and other termination signals to shutdown
trap terminate SIGINT SIGTERM SIGHUP

START_TIME=$(date +'%s')

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

INSECURE_REGISTRY_FLAG=
if [ "${INSECURE_REGISTRY}" == true ]; then
    INSECURE_REGISTRY_FLAG=--insecure-registry=${DOCKER_REGISTRY}
    echo "Adding ${INSECURE_REGISTRY_FLAG} to the Docker daemon"
fi

# Start the Docker daemon
echo "Starting docker daemon"
dockerd-entrypoint.sh ${INSECURE_REGISTRY_FLAG} > /dev/null 2>&1 &
DOCKER_PID=$!
disown ${DOCKER_PID}

# Allow time for daemon to start
echo "Allowing time for docker daemon to come up"
sleep 10

# Login to registry
echo "Docker login to ${DOCKER_REGISTRY}"
docker login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} ${DOCKER_REGISTRY} || exit 1

# Calculate the loop size
LOOP_SIZE=$(( ${NUMBER_OF_IMAGES} / ${NUM_OF_THREADS} ))
LOOP_REMAINDER=$(( ${NUMBER_OF_IMAGES} % ${NUM_OF_THREADS} ))

echo "LOOP_SIZE is ${LOOP_SIZE}"
echo "LOOP_REMAINDER is ${LOOP_REMAINDER}"

# A random sleep for multiple replicas to be out of sync
#sleep $(( $RANDOM % 20 ))

# Create the Docker images
if [ ${LOOP_SIZE} -gt 0 ]; then
    for a in $(seq 1 ${LOOP_SIZE}); do

        # Call the docker build script
        echo -e "\n\n[${a}/${LOOP_SIZE}] Preparing batch of ${NUM_OF_THREADS} images"
        for b in $(seq 1 ${NUM_OF_THREADS}); do
            sleep 2
            /run-docker-build-and-push.sh ${b} &
        done

        # Wait for all background processes to finish
        wait
    done
fi

# Do the remainder threads if needed
if [ ${LOOP_REMAINDER} -gt 0 ]; then
    echo -e "\n\n[Remainder (last batch)] Preparing batch of ${LOOP_REMAINDER} images"
    for b in $(seq 1 ${LOOP_REMAINDER}); do
        /run-docker-build-and-push.sh ${b} &
    done
fi

# Wait for all background processes to finish
wait

END_TIME=$(date +'%s')
ELAPSED_TIME=$(( ${END_TIME} - ${START_TIME} ))

echo -e "\nCompleted in ${ELAPSED_TIME} seconds"
