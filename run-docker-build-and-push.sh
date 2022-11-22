#!/bin/bash

# Build and push a single Docker image

[ "${DEBUG}" == true ] && set -x

THREAD=${1:-standalone}

logger () {
    echo "  [Thread ${THREAD}] ${1}"
}

# Create temp directory
GEN_DIR=$(mktemp -d)

NUMBER_OF_LAYERS=${NUMBER_OF_LAYERS:-1}
SIZE_OF_LAYER_KB=${SIZE_OF_LAYER_KB:-1}
NUM_OF_THREADS=${NUM_OF_THREADS:-1}
DOCKER_REGISTRY=${DOCKER_REGISTRY?Must set DOCKER_REGISTRY}
DOCKER_USER=${DOCKER_USER:-admin}
DOCKER_PASSWORD=${DOCKER_PASSWORD:-password}
REPO_PATH=${REPO_PATH:-docker-auto}
REMOVE_IMAGES=${REMOVE_IMAGES:-true}
TAG=${TAG:-1}
ERROR=false

logger "==== Creating Docker image"

# A common ID to be used later
GEN_ID=$(openssl rand -hex 4)

# Build Docker image
image_name_prefix="generated-${NUMBER_OF_LAYERS}x${SIZE_OF_LAYER_KB}kb"
image_name=${image_name_prefix}-${GEN_ID}-$(openssl rand -hex 16)
logger "Image name: ${image_name}"

# Create Dockerfile
echo 'FROM scratch' > ${GEN_DIR}/Dockerfile

# Create the files for the images
for b in $(seq 1 ${NUMBER_OF_LAYERS}); do
    file_name=$(openssl rand -hex 16)
    CMD="dd if=/dev/urandom of=${GEN_DIR}/${file_name} bs=${SIZE_OF_LAYER_KB} count=1024"
    if [ "${DEBUG}" == true ]; then
        logger "Command to run: ${CMD}"
        ${CMD} || ERROR=true
    else
        ${CMD} > /dev/null 2>&1 || ERROR=true
    fi
    if [ "${ERROR}" == true ]; then
        logger "ERROR: ${CMD} failed"
        exit 1
    fi
    file_size=$(ls -l ${GEN_DIR}/${file_name} | awk '{print $5}')
    logger "Created file ${file_name} (${file_size} bytes)"
    echo "COPY ${file_name} /files/" >> ${GEN_DIR}/Dockerfile
done

if [ "${DEBUG}" == true ]; then
    logger "Dockerfile to build"
    cat ${GEN_DIR}/Dockerfile
fi

# Build Docker image
logger "Building image ${image_name}"
CMD="docker build -t ${DOCKER_REGISTRY}/${REPO_PATH}/${image_name}:${TAG} ${GEN_DIR}/"

if [ "${DEBUG}" == true ]; then
    logger "Command to run: ${CMD}"
    ${CMD} || ERROR=true
else
    ${CMD} > /dev/null 2>&1 || ERROR=true
fi

if [ "${ERROR}" == true ]; then
    logger "ERROR: ${CMD} failed"
    exit 1
fi

# Cleanup
logger "Removing temp directory"
rm -rf ${GEN_DIR}

if [ "${DEBUG}" == true ]; then
    # List Docker images
    logger "Generated Docker image"
    docker images | grep ${image_name_prefix}-${GEN_ID}
fi

# Push images
logger "Pushing Docker images"
for a in $(docker images | grep ${image_name_prefix}-${GEN_ID} | awk '{print $1}'); do
    logger "Pushing ${a}:${TAG}"
    CMD="docker push ${a}:${TAG}"
    if [ "${DEBUG}" == true ]; then
        logger "Command to run: ${CMD}"
    fi
    ${CMD} || ERROR=true
done

if [ "${REMOVE_IMAGES}" == true ]; then
    logger "REMOVE_IMAGES is true. Removing generated images"
    docker images | grep ${image_name_prefix}-${GEN_ID} | awk '{print $3}' | xargs docker rmi -f > /dev/null 2>&1
fi

if [ "${ERROR}" == true ]; then
    logger "*********** ERRORS found ***********"
fi
logger "Completed"
