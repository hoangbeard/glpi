#!/bin/bash


# Constants
ECR_TAG='3cfa327'
AWS_REGION=ap-southeast-1
AWS_ACCOUNT_ID=640853836543
ECR_REPO_ENDPOINT="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"


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

# Download sources
download_glpi() {
    echo "----- Downloading GLPI source -----"
    GLPI_LATEST_VERSION=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | grep tag_name | cut -d '"' -f 4)
    
    if [ -z $GLPI_VERSION ]; then 
        GLPI_VERSION=$GLPI_LATEST_VERSION
        echo "GLPI Version: ${GLPI_VERSION}"
    elif [ "$GLPI_VERSION" != "$GLPI_LATEST_VERSION" ]; then
        echo "Notice: Current version ($GLPI_VERSION) differs from latest version ($GLPI_LATEST_VERSION)"
        echo "Would you like to:"
        echo "1) Keep current version ($GLPI_VERSION)"
        echo "2) Use latest version ($GLPI_LATEST_VERSION)"
        read -p "Enter your choice (1 or 2): " version_choice
        
        case $version_choice in
            2)
                GLPI_VERSION=$GLPI_LATEST_VERSION
                echo "Switching to latest version: $GLPI_VERSION"
                ;;
            *)
                echo "Keeping current version: $GLPI_VERSION"
                ;;
        esac
    else
        echo "GLPI Version: ${GLPI_VERSION}"
    fi

    GLPI_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/tags/${GLPI_VERSION} | grep browser_download_url | cut -d '"' -f 4)

    if [ ! -f "glpi-${GLPI_VERSION}.tgz" ]; then
        wget -q -P . ${GLPI_DOWNLOAD_URL}
    fi
    echo "Download GLPI source done."

    echo "----- Downloading GLPI SAML plugin -----"
    if [ -z $GLPI_SAML_VERSION ]; then
        GLPI_SAML_VERSION=v1.1.10
    fi

    GLPI_SAML_DOWNLOAD_URL="https://codeberg.org/QuinQuies/glpisaml/releases/download/${GLPI_SAML_VERSION}/glpisaml.zip"

    if [ ! -f glpisaml.zip ]; then
        wget -q -P . ${GLPI_SAML_DOWNLOAD_URL}
    fi
    echo "Download GLPI SAML plugin done."
}

deploy_glpi() {
    echo "----- Extracting files -----"
    mkdir -p glpi
    tar -xzf "glpi-${GLPI_VERSION}.tgz" -C glpi --strip-components=1
    unzip -q glpisaml.zip -d glpi/plugins/
    echo "Extract files done."

    echo "----- Copying files -----"
    cp php-fpm/config/downstream.php glpi/inc/
    cp -r glpi nginx/glpi
    cp -r glpi php-fpm/glpi
    echo "Copy files done."
}

cleanup_glpi() {
    echo "----- Cleaning up files -----"
    rm -rf glpi
    rm -rf nginx/glpi
    rm -rf php-fpm/glpi
    echo "Clean up done."
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
        docker login
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

    'compose')
        load_env
        cleanup_glpi
        download_glpi
        deploy_glpi
        docker compose up -d --build
        cleanup_glpi
esac

echo ""
echo "------------------------------"
echo "Bootstrap execution completed."
echo "------------------------------"