# GLPI Docker

This is a Docker image for [GLPI](https://glpi-project.org/) with HTTPS support.

## Requirements

- Docker
- Docker Compose

## Usage

### Run testing

1. Clone this repository

    ```bash
    git clone https://github.com/hoangbeard/glpi
    ```

2. Configure environment variables (optional)

    ```bash
    cd glpi/app-image
    cp .env.example .env
    # Edit .env file to customize settings
    ```

3. Run following script to start docker compose

    ```bash
    chmod +x bootstrap.sh
    docker compose up --build
    ```

4. Open your browser and go to `https://glpi.localhost` (you may need to add this to your hosts file)

### HTTPS Configuration

The Docker image supports two modes for HTTPS:

1. **Self-signed certificates** (default)
   - Automatically generates self-signed certificates for development/testing
   - Default configuration uses "localhost" if no domain is specified
   - You can customize the domain by setting the `GLPI_DOMAIN` environment variable
   - You will need to accept the security warning in your browser

2. **Let's Encrypt certificates**
   - For production use with valid certificates
   - Requires a public domain with DNS pointing to your server
   - Set the following environment variables in your .env file:
     ```
     GLPI_HTTPS_MODE=letsencrypt
     GLPI_DOMAIN=your-domain.com
     GLPI_EMAIL=your-email@example.com
     ```

### Accessing GLPI

- If using the default configuration with self-signed certificates:
  - Access GLPI at `https://localhost`
  - You may need to accept the security warning in your browser

- If using a custom domain:
  - Make sure the domain is properly configured in your DNS or hosts file
  - Access GLPI at `https://your-domain.com`

### Run build and push

1. Clone this repository

    ```bash
    git clone https://github.com/hoangbeard/glpi
    ```

2. Run following script to start docker compose

    ```bash
    cd glpi/app-image
    chmod +x bootstrap.sh
    ./bootstrap.sh build-push
    ```

    ***Notice: Check the contents of the .env file before running the script.***

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
