#!/bin/bash


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

# Define directories and initialize structure
init_directories() {
    echo "Initializing directories..."
    source_code_dir="sources"
    plugins_dir="$source_code_dir/plugins"

    rm -rf glpi
    mkdir -p "$source_code_dir" "$plugins_dir" "glpi"
    echo "Initial directories complete."
}

# Load environment variables
load_env() {
    echo "Setting environment variables..."
    if [ ! -f .env ]; then
        mv .env.sample .env
    fi
    set -a
    source .env
    set +a
    echo "Set environment variables complete."
}

# Download GLPI source
download_glpi() {
    GLPI_SOURCE="$source_code_dir/glpi-${GLPI_VERSION}.tgz"
    if [ ! -f "$GLPI_SOURCE" ]; then
        echo "Downloading GLPI source..."
        wget -q -P "$source_code_dir" \
            "https://github.com/glpi-project/glpi/releases/download/${GLPI_VERSION}/glpi-${GLPI_VERSION}.tgz"
        echo "Download GLPI source complete."
    fi
}

# Download GLPI SAML plugin
download_plugin() {
    SAML_PLUGIN="$plugins_dir/glpisaml.zip"
    if [ ! -f "$SAML_PLUGIN" ]; then
        echo "Downloading GLPI SAML plugin..."
        wget -q -P "$plugins_dir" \
            "https://codeberg.org/QuinQuies/glpisaml/releases/download/${GLPI_SAML_VERSION}/glpisaml.zip"
        echo "Download GLPI SAML plugin complete."
    fi
}

# Extract files
extract_files() {
    echo "Extracting GLPI files..."
    tar -xzf "$GLPI_SOURCE" -C glpi --strip-components=1
    unzip -q "$SAML_PLUGIN" -d glpi/plugins/
    echo "Extract complete."
}

# Deploy files to web servers
deploy_files() {
    echo "Deploying files..."
    rm -rf nginx/glpi php-fpm/glpi
    cp -a glpi nginx/glpi
    cp -a glpi php-fpm/glpi
    echo "Deployment complete."
}

# Function to build docker images
build_docker_image() {
    local service=$1

    # Main execution
    init_directories
    load_env
    download_glpi
    download_plugin
    extract_files
    deploy_files

    echo "Building ${service} docker image..."
    docker buildx build \
        --tag ${GIT_REPO_URL}:${service} \
        --file ${service}/Dockerfile ${service}/
    echo "Building ${service} docker image done!"
}

# Function to push docker images
push_docker_image() {
    local service=$1

    # Main execution
    load_env

    echo "Pushing ${service} docker image..."
    docker push ${GIT_REPO_URL}:${service}
    echo "Pushing ${service} docker image done!"
}

# Process command line argument
case $1 in
    'build')
        build_docker_image "nginx"
        build_docker_image "php-fpm"
        ;;

    'push')
        push_docker_image "nginx"
        push_docker_image "php-fpm"
        ;;

    'build-push')
        build_docker_image "nginx"
        build_docker_image "php-fpm"
        push_docker_image "nginx"
        push_docker_image "php-fpm"
        ;;

    'compose')
        # Main execution
        init_directories
        load_env
        download_glpi
        download_plugin
        extract_files
        deploy_files
        echo "Docker composing..."
        echo "==================="
        docker compose up -d
        docker compose ps
        ;;
esac

echo "============================"
echo "Script execution completed.!"
