# Docker Images Generator
Generate randomly named Docker images made up of unique layers with a given layer size and number of layers (`layer size` X `number of layers` = `image total size`) and upload them to a Docker registry.

The build and upload can run in parallel processes for increased load and saving time.

## Use case
I use this to upload unique Docker images and load test my [Artifactory](https://jfrog.com/artifactory/) instance, which is also my Docker registry.

## Design
The generator runs in a Docker container, generating images based on pre-defined parameters and then uploads to the defined Docker registry.

## Build Docker image
Build the Docker image
```bash
export REGISTRY=
export REPOSITORY=
export TAG=

docker build -t ${REGISTRY}/${REPOSITORY}:${TAG} .
```

## Running Generator 

### Run Docker container
You can run the Docker container directly on your Docker enabled host (needs the `--privileged` to work). You can use the already built image `eldada-docker-examples.bintray.io/docker-data-generator:0.9`
```bash
# Example for creating 100 images with 10 layers 1MB each and uploading to docker.artifactory/test
# in 3 parallel sub processes (the 100 images are slit between the processes).
export REGISTRY=eldada-docker-examples.bintray.io
export REPOSITORY=docker-data-generator
export TAG=0.9

export DEBUG=
export NUMBER_OF_IMAGES=100
export NUMBER_OF_LAYERS=10
export SIZE_OF_LAYER_KB=1024
export NUM_OF_THREADS=3
export DOCKER_REGISTRY=docker.artifactory
export INSECURE_REGISTRY=true
export DOCKER_USER=${YOUR_DOCKER_USERNAME}
export DOCKER_PASSWORD=${YOUR_DOCKER_PASSWORD}
export REPO_PATH=test
export REMOVE_IMAGES=true


docker run --rm --name docker-data-gen \
    -e NUMBER_OF_IMAGES=${NUMBER_OF_IMAGES} \
    -e NUMBER_OF_LAYERS=${NUMBER_OF_LAYERS} \
    -e SIZE_OF_LAYER_KB=${SIZE_OF_LAYER_KB} \
    -e NUM_OF_THREADS=${NUM_OF_THREADS} \
    -e DOCKER_REGISTRY=${DOCKER_REGISTRY} \
    -e INSECURE_REGISTRY=${INSECURE_REGISTRY} \
    -e DOCKER_USER=${DOCKER_USER} \
    -e DOCKER_PASSWORD=${DOCKER_PASSWORD} \
    -e REPO_PATH=${REPO_PATH} \
    -e REMOVE_IMAGES=${REMOVE_IMAGES} \
    -e TAG=${TAG} \
    --privileged \
    ${REGISTRY}/${REPOSITORY}:${TAG}
```

### Run in Kubernetes with provided Helm chart
It's possible to deploy the Docker image generator with the helm chart in [docker-image-generator](docker-image-generator).

It's recommended to prepare a custom `values.yaml` file for each scenario with the custom `env` needed. See [values-example-1gb.yaml](docker-image-generator/values-example-1gb.yaml) as example.

Be aware that the Job is set to run with `privileged: true`
```
...
    securityContext:
      privileged: true
...
```

#### Deploy
**IMPORTANT:** The Job deployed in K8s is not removed after completed, so you'll need to remove a deployed release before deploying again
```bash
# Deploy
cd docker-image-generator
helm upgrade --install data-gen -f values-1gb.yaml .

# Remove once done
helm delete --purge data-gen

```


