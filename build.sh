#!/usr/bin/env bash

# Do a multistage build

export DOCKER_BUILDKIT=1
export DOCKER_CLI_EXPERIMENTAL=enabled
export BUILDKIT_PROGRESS=plain

if ! docker buildx inspect multiarch > /dev/null; then
    docker buildx create --name multiarch
fi
docker buildx use multiarch

if [[ "$*" == *--push* ]]; then
    if [[ -n "$DOCKER_USERNAME" ]] && [[ -n "$DOCKER_PASSWORD" ]]; then
        echo "Logging into docker registry $DOCKER_REGISTRY_URL...."
        echo "$DOCKER_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin $DOCKER_REGISTRY_URL
    fi
fi

if [[ -z "$PLATFORMS" ]]; then
    PLATFORMS="linux/amd64,linux/arm64,linux/arm/v7"
fi

docker buildx build --platform $PLATFORMS . $*

