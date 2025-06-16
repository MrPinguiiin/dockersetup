#!/bin/bash

# dockersetup.sh
# Automated PostgreSQL and Redis Dockerized Deployment Script
# Designed for various Linux distributions (Ubuntu, Fedora, Arch, CentOS, openSUSE)
# Ensures automatic container startup upon system reboot.

# --- Configuration Variables ---
# You can set these as environment variables before running the script to bypass prompts, e.g.:
# export PG_VERSION="16"
# export REDIS_VERSION="7"
# export PG_DATA_PATH="/data/postgresql_data"
# export REDIS_DATA_PATH="/data/redis_data"
# export PG_PORT="5432"
# export REDIS_PORT="6379"
# export PG_USER="myuser"
# export PG_DB="mydb"
# export PG_PASSWORD="your_strong_postgres_password"
# export REDIS_PASSWORD="your_strong_redis_password" # Set to empty if no Redis password is desired

# Default values if not set via environment variables (for Redis only)
PG_VERSION=${PG_VERSION:-"16"}
REDIS_VERSION=${REDIS_VERSION:-"7"}
PG_DATA_PATH=${PG_DATA_PATH:-"/data/postgresql_data"}
REDIS_DATA_PATH=${REDIS_DATA_PATH:-"/data/redis_data"}
PG_PORT=${PG_PORT:-"5432"}
REDIS_PORT=${REDIS_PORT:-"6379"}

# --- Prompt for PostgreSQL and Redis Credentials ---
log "--- Database Configuration ---"

# Prompt for PostgreSQL User
if [ -z "$PG_USER" ]; then
    read -p "Enter PostgreSQL username (default: dockeruser): " INPUT_PG_USER
    PG_USER=${INPUT_PG_USER:-"dockeruser"}
fi

# Prompt for PostgreSQL Database Name
if [ -z "$PG_DB" ]; then
    read -p "Enter PostgreSQL database name (default: mydatabase): " INPUT_PG_DB
    PG_DB=${INPUT_PG_DB:-"mydatabase"}
fi

# Prompt for PostgreSQL Password
if [ -z "$PG_PASSWORD" ]; then
    while true; do
        read -sp "Enter PostgreSQL password for '$PG_USER': " PG_PASSWORD
        echo
        if [ -z "$PG_PASSWORD" ]; then
            echo "Error: PostgreSQL password cannot be empty. Please try again."
        else
            break
        fi
    done
fi

# Prompt for Redis Password
if [ -z "$REDIS_PASSWORD" ]; then
    read -sp "Enter Redis password (leave empty for no password): " REDIS_PASSWORD
    echo
fi

log "PostgreSQL User: $PG_USER"
log "PostgreSQL Database: $PG_DB"
log "------------------------------"


# --- Functions ---

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

error_exit() {
    log "ERROR: $1" >&2
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Please run this script with root privileges (sudo)."
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION_ID=$VERSION_ID

        # For Debian/Ubuntu-based systems (including Linux Mint), we need to determine the correct codename
        # for Docker repositories. Prioritize UBUNTU_CODENAME if available, then fallback to VERSION_CODENAME
        # for non-Mint or older Debian/Ubuntu that might not have UBUNTU_CODENAME.
        if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" || "$OS_NAME" == "linuxmint" ]]; then
            # UBUNTU_CODENAME is most accurate for Linux Mint
            if [ -n "$UBUNTU_CODENAME" ]; then
                REPO_CODENAME=$UBUNTU_CODENAME
                log "Using UBUNTU_CODENAME for Docker repository: $REPO_CODENAME"
            elif [ -n "$VERSION_CODENAME" ]; then # For Debian or older Ubuntu that might not have UBUNTU_CODENAME
                REPO_CODENAME=$VERSION_CODENAME
                log "Using VERSION_CODENAME for Docker repository: $REPO_CODENAME"
            else
                error_exit "Could not determine suitable release codename for Docker repository."
            fi
        else
            # For non-Debian/Ubuntu OS, REPO_CODENAME is not relevant for their specific repositories
            REPO_CODENAME="" # Empty as it's not used
        fi

    else
        error_exit "Could not detect OS. This script might not be compatible."
    fi
    log "Detected OS: $OS_NAME $OS_VERSION_ID"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed. Skipping Docker installation."
        return 0
    fi

    log "Docker not found. Installing Docker..."

    case "$OS_NAME" in
        ubuntu|debian|linuxmint)
            log "Installing Docker on Debian/Ubuntu-based system..."
            # Remove old Docker installations to prevent conflicts
            log "Removing old Docker installations (if any)..."
            for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
                sudo apt-get remove -y "$pkg" 2>/dev/null
            done

            sudo apt update || error_exit "Failed to update apt."
            sudo apt install -y ca-certificates curl gnupg lsb-release || error_exit "Failed to install prerequisites."

            sudo install -m 0755 -d /etc/apt/keyrings || error_exit "Failed to create keyrings directory."
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc || error_exit "Failed to download Docker GPG key."
            sudo chmod a+r /etc/apt/keyrings/docker.asc || error_exit "Failed to set permissions for GPG key."
            
            # Use the universally determined REPO_CODENAME
            if [ -z "$REPO_CODENAME" ]; then
                error_exit "Internal error: REPO_CODENAME is undefined for Docker installation."
            fi
            echo \
              "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
              "${REPO_CODENAME}" stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Failed to add Docker repository."
            
            sudo apt update || error_exit "Failed to update apt after adding Docker repo."
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Failed to install Docker components."
            ;;
        fedora|centos|rhel|almalinux|rocky)
            log "Installing Docker on RHEL-based system..."
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || error_exit "Failed to add Docker repo."
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Failed to install Docker components."
            sudo systemctl start docker || error_exit "Failed to start Docker service."
            sudo systemctl enable docker || error_exit "Failed to enable Docker service."
            ;;
        arch)
            log "Installing Docker on Arch Linux..."
            sudo pacman -Syu --noconfirm docker || error_exit "Failed to install Docker."
            sudo systemctl start docker || error_exit "Failed to start Docker service."
            sudo systemctl enable docker || error_exit "Failed to enable Docker service."
            ;;
        opensuse-leap|sles)
            log "Installing Docker on openSUSE/SLES..."
            sudo zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo || error_exit "Failed to add Docker repo."
            sudo zypper refresh || error_exit "Failed to refresh zypper."
            sudo zypper install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin || error_exit "Failed to install Docker components."
            sudo systemctl start docker || error_exit "Failed to start Docker service."
            sudo systemctl enable docker || error_exit "Failed to enable Docker service."
            ;;
        *)
            error_exit "Unsupported OS: $OS_NAME. Please install Docker manually."
            ;;
    esac

    # Add current user to docker group (for non-root docker commands)
    # This must be done after Docker installation, as the 'docker' group is created by Docker packages.
    if ! getent group docker > /dev/null; then
        sudo groupadd docker || error_exit "Failed to create docker group."
    fi
    sudo usermod -aG docker "$SUDO_USER" || error_exit "Failed to add user to docker group."
    log "User '$SUDO_USER' added to 'docker' group. You may need to log out/in or reboot for changes to take effect for non-sudo docker commands."
    log "Docker installation complete."
}

create_docker_compose_file() {
    log "Creating Docker Compose file..."
    mkdir -p "$PG_DATA_PATH" || error_exit "Failed to create PostgreSQL data directory."
    mkdir -p "$REDIS_DATA_PATH" || error_exit "Failed to create Redis data directory."

    cat <<EOF > docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:${PG_VERSION}
    container_name: postgres_db
    restart: always
    environment:
      POSTGRES_USER: ${PG_USER}
      POSTGRES_PASSWORD: ${PG_PASSWORD}
      POSTGRES_DB: ${PG_DB}
    volumes:
      - ${PG_DATA_PATH}:/var/lib/postgresql/data
    ports:
      - "${PG_PORT}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PG_USER} -d ${PG_DB}"]
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:${REDIS_VERSION}-alpine
    container_name: redis_cache
    restart: always
    volumes:
      - ${REDIS_DATA_PATH}:/data
    ports:
      - "${REDIS_PORT}:6379"
    command: ${REDIS_PASSWORD:+redis-server --requirepass "${REDIS_PASSWORD}"}
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "info"]
      interval: 5s
      timeout: 5s
      retries: 5

EOF
    log "Docker Compose file 'docker-compose.yml' created successfully."
    log "PostgreSQL data will be stored in: $PG_DATA_PATH"
    log "Redis data will be stored in: $REDIS_DATA_PATH"
}

deploy_containers() {
    log "Pulling Docker images and deploying containers..."
    # Ensure Docker is running before trying to use compose
    # Note: docker-ce and containerd.io automatically enable and start the docker service
    # when installed from official repositories. This is a double-check.
    sudo systemctl is-active docker || sudo systemctl start docker || error_exit "Docker service is not running and failed to start."
    sudo systemctl is-enabled docker || sudo systemctl enable docker || error_exit "Docker service is not enabled and failed to enable."

    # Use the docker compose plugin which is the modern standard method
    if command -v docker &>/dev/null && docker compose version &> /dev/null; then
        log "Using 'docker compose' plugin..."
        sudo docker compose pull || error_exit "Failed to pull Docker images with docker compose."
        sudo docker compose up -d || error_exit "Failed to deploy containers with docker compose."
    else
        error_exit "The 'docker compose' plugin was not found or Docker is not installed correctly. Please check your Docker installation."
        # Fallback to docker-compose standalone if still needed (rare after 2021)
        # if ! command -v docker-compose &> /dev/null; then
        #      error_exit "The docker-compose command was not found. Ensure Docker Compose plugin is installed or install docker-compose manually."
        # fi
        # sudo docker-compose pull || error_exit "Failed to pull Docker images with docker-compose."
        # sudo docker-compose up -d || error_exit "Failed to deploy containers with docker-compose."
    fi
    log "Containers deployed successfully."
}

# --- Main Script Execution ---

check_root
detect_os
install_docker # This also handles adding user to docker group. User might need to re-login.

# Give some time for Docker service to be fully up after installation
sleep 5

create_docker_compose_file
deploy_containers

log "--- Deployment Complete! ---"
log "PostgreSQL (v$PG_VERSION) is running on port $PG_PORT (container: postgres_db)"
log "  User: $PG_USER"
log "  Database: $PG_DB"
log "  Data Path: $PG_DATA_PATH"
log "Redis (v$REDIS_VERSION) is running on port $REDIS_PORT (container: redis_cache)"
log "  Data Path: $REDIS_DATA_PATH"
if [ -n "$REDIS_PASSWORD" ]; then
    log "  Redis is configured with a password."
else
    log "  Redis is configured WITHOUT a password (less secure, consider adding one)."
fi
log ""
log "To check container status: sudo docker ps"
log "To view logs for PostgreSQL: sudo docker logs postgres_db"
log "To view logs for Redis: sudo docker logs redis_cache"
log "Containers are configured to restart automatically on system reboot."
log ""
log "IMPORTANT: If Docker was just installed, you may need to log out and log back in (or reboot) for your user to be able to run 'docker' commands without 'sudo'."
log "Remember to configure your firewall (e.g., ufw, firewalld) to allow incoming connections to ports $PG_PORT and $REDIS_PORT if accessed externally."