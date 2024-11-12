#!/bin/bash


# Constants
ECR_TAG='3cfa327'


# Check if arguments are provided and validate
if [ $# -ne 1 ]; then
    echo "Usage: $0 [build|push|build-push|compose]"
    echo "Please provide exactly one argument"
    exit 1
fi

# Validate argument is in allowed list
if [[ ! $1 =~ ^(build|push|build-push|compose)$ ]]; then
    echo "Error: Invalid argument '$1'"
    echo "Usage: $0 [build|push|build-push|compose]"
    echo "Please provide one of the allowed arguments"
    exit 1
fi

# Load environment variables
load_env() {
    echo "Setting environment variables..."
    if [ ! -f .env ]; then
        cp .env.sample .env
    fi
    set -a
    source .env
    set +a
    echo "Set environment variables complete."
}

# Function to authenticate Docker to Docker Hub or AWS ECR
authenticate_docker() {
    local repo_url=$1
    
    # Check if the repository URL is an AWS ECR URL
    if [[ "$repo_url" =~ ^[0-9]+\.dkr\.ecr\.[a-z0-9-]+\.amazonaws\.com ]]; then
        echo "AWS ECR repository detected, authenticating with AWS ECR..."
        if [ -z "${AWS_REGION}" ] || [ -z "${AWS_ACCOUNT_ID}" ]; then
            echo "Error: AWS_REGION and AWS_ACCOUNT_ID environment variables must be set for ECR authentication"
            exit 1
        else
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "${ECR_REPO_ENDPOINT}"
        fi
    else
        echo "Docker Hub repository detected, authenticating with Docker Hub..."
        if [ -z "${DOCKER_USERNAME}" ]  [ -z "${DOCKER_PASSWORD}" ]; then
            echo "Error: DOCKER_USERNAME and DOCKER_PASSWORD environment variables must be set for Docker Hub authentication"
            exit 1
        else
            # echo "${DOCKER_PASSWORD}" | docker login -u "${DOCKER_USERNAME}" --password-stdin
            docker login
        fi
    fi
}

# Function to build docker images
build_docker_image() {
    local service=$1
    local tag=$2
    
    echo "Building ${service} docker image..."
    docker buildx build --build-arg BUILDKIT_INLINE_CACHE=1 \
    --tag "${ECR_REPO_ENDPOINT}/glpi-${service}:latest" \
    --tag "${ECR_REPO_ENDPOINT}/glpi-${service}:${tag}" \
    --file ${service}/Dockerfile \
    ${service}/

    echo "Building ${service} docker image done."
}

# Function to push docker images
push_docker_image() {
    local service=$1
    local tag=$2
    
    echo "Pushing ${service} docker image..."
    docker image push "${ECR_REPO_ENDPOINT}/glpi-${service}:latest"
    docker image push "${ECR_REPO_ENDPOINT}/glpi-${service}:${tag}"
    echo "Pushing ${service} docker image done!"
}

# Process command line argument
case $1 in
    'build')
        # Main execution
        load_env
        build_docker_image "nginx" "${ECR_TAG}"
        build_docker_image "php-fpm" "${ECR_TAG}"
    ;;
    
    'push')
        # Main execution
        load_env
        authenticate_docker $ECR_REPO_ENDPOINT
        push_docker_image "nginx" "${ECR_TAG}"
        push_docker_image "php-fpm" "${ECR_TAG}"
    ;;
    
    'build-push')
        # Main execution
        load_env
        build_docker_image "nginx" "${ECR_TAG}"
        build_docker_image "php-fpm" "${ECR_TAG}"
        authenticate_docker $ECR_REPO_ENDPOINT
        push_docker_image "nginx" "${ECR_TAG}"
        push_docker_image "php-fpm" "${ECR_TAG}"
    ;;
esac

echo "------------------------------"
echo "Bootstrap execution completed."