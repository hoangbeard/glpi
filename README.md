# GLPI Docker

This is a Docker image for [GLPI](https://glpi-project.org/).

## Requirements

- Docker
- Docker Compose

## Usage

### Run testing

1. Clone this repository

    ```bash
    git clone https://github.com/hoangbeard/glpi
    ```

2. Run following script to start docker compose

    ```bash
    cd glpi/docker
    chmod +x bootstrap.sh
    docker compose up --build
    ```

3. Open your browser and go to `http://localhost`

### Run build and push

1. Clone this repository

    ```bash
    git clone https://github.com/hoangbeard/glpi
    ```

2. Run following script to start docker compose

    ```bash
    cd glpi/docker
    chmod +x bootstrap.sh
    ./bootstrap.sh build-push
    ```

    ***Notice: Check the contents of the .env file before running the script.***

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
