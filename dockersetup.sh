#!/bin/bash

# dockersetup.sh
# Skrip Deployment Otomatis PostgreSQL dan Redis dengan Docker
# Dirancang untuk berbagai distribusi Linux (Ubuntu, Fedora, Arch, CentOS, openSUSE)
# Memastikan startup otomatis container saat sistem di-reboot.

# --- Variabel Konfigurasi ---
# Anda bisa mengatur ini sebagai variabel lingkungan sebelum menjalankan skrip, contoh:
# export PG_VERSION="16"
# export REDIS_VERSION="7"
# export PG_DATA_PATH="/data/postgresql_data"
# export REDIS_DATA_PATH="/data/redis_data"
# export PG_PORT="5432"
# export REDIS_PORT="6379"
# export PG_USER="dockeruser"
# export PG_DB="mydatabase"
# export PG_PASSWORD="your_strong_postgres_password" # <-- PENTING: Ganti ini!
# export REDIS_PASSWORD="your_strong_redis_password" # <-- PENTING: Ganti ini jika menggunakan Redis auth!

# Nilai default jika tidak diatur melalui variabel lingkungan
PG_VERSION=${PG_VERSION:-"16"}
REDIS_VERSION=${REDIS_VERSION:-"7"}
PG_DATA_PATH=${PG_DATA_PATH:-"/data/postgresql_data"}
REDIS_DATA_PATH=${REDIS_DATA_PATH:-"/data/redis_data"}
PG_PORT=${PG_PORT:-"5432"}
REDIS_PORT=${REDIS_PORT:-"6379"}
PG_USER=${PG_USER:-"dockeruser"}
PG_DB=${PG_DB:-"mydatabase"}

# --- PENTING: Minta kata sandi jika tidak diatur sebagai variabel lingkungan ---
if [ -z "$PG_PASSWORD" ]; then
    read -sp "Masukkan kata sandi PostgreSQL untuk '$PG_USER': " PG_PASSWORD
    echo
    if [ -z "$PG_PASSWORD" ]; then
        echo "Error: Kata sandi PostgreSQL tidak boleh kosong. Keluar."
        exit 1
    fi
fi

if [ -z "$REDIS_PASSWORD" ]; then
    read -sp "Masukkan kata sandi Redis (biarkan kosong untuk tanpa kata sandi): " REDIS_PASSWORD
    echo
fi

# --- Variabel Global ---
DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)"
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"

# --- Fungsi ---

log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1"
}

error_exit() {
    log "ERROR: $1" >&2
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error_exit "Silakan jalankan skrip ini dengan hak akses root (sudo)."
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION_ID=$VERSION_ID
    else
        error_exit "Tidak dapat mendeteksi OS. Skrip ini mungkin tidak kompatibel."
    fi
    log "OS terdeteksi: $OS_NAME $OS_VERSION_ID"
}

install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker sudah terinstal. Melewatkan instalasi Docker."
        return 0
    fi

    log "Docker tidak ditemukan. Menginstal Docker..."

    case "$OS_NAME" in
        ubuntu|debian|linuxmint)
            log "Menginstal Docker pada sistem berbasis Debian..."
            sudo apt update || error_exit "Gagal memperbarui apt."
            sudo apt install -y ca-certificates curl gnupg lsb-release || error_exit "Gagal menginstal prasyarat."
            sudo install -m 0755 -d /etc/apt/keyrings || error_exit "Gagal membuat direktori keyrings."
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg || error_exit "Gagal menambahkan kunci GPG Docker."
            sudo chmod a+r /etc/apt/keyrings/docker.gpg || error_exit "Gagal mengatur izin untuk kunci GPG."
            
            # Mendapatkan codename yang benar. Untuk Mint, gunakan codename Ubuntu dasarnya.
            . /etc/os-release
            if [ "$ID" = "linuxmint" ]; then
                CODENAME="$UBUNTU_CODENAME"
            else
                CODENAME="$VERSION_CODENAME"
            fi

            echo \
              "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              \"$CODENAME\" stable" | \
              sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || error_exit "Gagal menambahkan repositori Docker."
            sudo apt update || error_exit "Gagal memperbarui apt setelah menambahkan repo Docker."
            sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Gagal menginstal komponen Docker."
            ;;
        fedora|centos|rhel|almalinux|rocky)
            log "Menginstal Docker pada sistem berbasis RHEL..."
            sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo || error_exit "Gagal menambahkan repo Docker."
            sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || error_exit "Gagal menginstal komponen Docker."
            sudo systemctl start docker || error_exit "Gagal memulai layanan Docker."
            sudo systemctl enable docker || error_exit "Gagal mengaktifkan layanan Docker."
            ;;
        arch)
            log "Menginstal Docker pada Arch Linux..."
            sudo pacman -Syu --noconfirm docker || error_exit "Gagal menginstal Docker."
            sudo systemctl start docker || error_exit "Gagal memulai layanan Docker."
            sudo systemctl enable docker || error_exit "Gagal mengaktifkan layanan Docker."
            ;;
        opensuse-leap|sles)
            log "Menginstal Docker pada openSUSE/SLES..."
            sudo zypper addrepo https://download.docker.com/linux/opensuse/docker-ce.repo || error_exit "Gagal menambahkan repo Docker."
            sudo zypper refresh || error_exit "Gagal me-refresh zypper."
            sudo zypper install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin || error_exit "Gagal menginstal komponen Docker."
            sudo systemctl start docker || error_exit "Gagal memulai layanan Docker."
            sudo systemctl enable docker || error_exit "Gagal mengaktifkan layanan Docker."
            ;;
        *)
            error_exit "OS tidak didukung: $OS_NAME. Silakan instal Docker secara manual."
            ;;
    esac

    # Tambahkan pengguna saat ini ke grup docker (untuk perintah docker non-root)
    if ! getent group docker > /dev/null; then
        sudo groupadd docker || error_exit "Gagal membuat grup docker."
    fi
    sudo usermod -aG docker "$SUDO_USER" || error_exit "Gagal menambahkan pengguna ke grup docker."
    log "Pengguna '$SUDO_USER' ditambahkan ke grup 'docker'. Anda mungkin perlu keluar/masuk atau reboot agar perubahan berlaku untuk perintah docker tanpa sudo."
    log "Instalasi Docker selesai."
}

create_docker_compose_file() {
    log "Membuat file Docker Compose..."
    mkdir -p "$PG_DATA_PATH" || error_exit "Gagal membuat direktori data PostgreSQL."
    mkdir -p "$REDIS_DATA_PATH" || error_exit "Gagal membuat direktori data Redis."

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
    log "File Docker Compose 'docker-compose.yml' berhasil dibuat."
    log "Data PostgreSQL akan disimpan di: $PG_DATA_PATH"
    log "Data Redis akan disimpan di: $REDIS_DATA_PATH"
}

deploy_containers() {
    log "Menarik image Docker dan melakukan deployment container..."
    # Pastikan Docker berjalan sebelum mencoba menggunakan compose
    sudo systemctl is-active docker || sudo systemctl start docker || error_exit "Layanan Docker tidak berjalan dan gagal dimulai."
    sudo systemctl is-enabled docker || sudo systemctl enable docker || error_exit "Layanan Docker tidak aktif dan gagal diaktifkan."

    # Gunakan plugin docker compose jika tersedia, jika tidak kembali ke docker-compose eksternal
    if docker compose version &> /dev/null; then
        sudo docker compose pull || error_exit "Gagal menarik image Docker dengan docker compose."
        sudo docker compose up -d || error_exit "Gagal melakukan deployment container dengan docker compose."
    else
        # Fallback untuk instalasi Docker yang lebih lama tanpa plugin atau docker-compose eksternal
        if ! command -v docker-compose &> /dev/null; then
             error_exit "Perintah docker-compose tidak ditemukan. Pastikan plugin Docker Compose terinstal atau instal docker-compose secara manual."
        fi
        sudo docker-compose pull || error_exit "Gagal menarik image Docker dengan docker-compose."
        sudo docker-compose up -d || error_exit "Gagal melakukan deployment container dengan docker-compose."
    fi
    log "Container berhasil di-deploy."
}

# --- Eksekusi Skrip Utama ---

check_root
detect_os
install_docker # Ini juga menangani penambahan pengguna ke grup docker. Pengguna mungkin perlu login ulang.

# Beri waktu agar layanan Docker sepenuhnya aktif setelah instalasi
sleep 5

create_docker_compose_file
deploy_containers

log "--- Deployment Selesai! ---"
log "PostgreSQL (v$PG_VERSION) berjalan di port $PG_PORT (container: postgres_db)"
log "  Pengguna: $PG_USER"
log "  Database: $PG_DB"
log "  Jalur Data: $PG_DATA_PATH"
log "Redis (v$REDIS_VERSION) berjalan di port $REDIS_PORT (container: redis_cache)"
log "  Jalur Data: $REDIS_DATA_PATH"
if [ -n "$REDIS_PASSWORD" ]; then
    log "  Redis dikonfigurasi dengan kata sandi."
else
    log "  Redis dikonfigurasi TANPA kata sandi (kurang aman, pertimbangkan untuk menambahkannya)."
fi
log ""
log "Untuk memeriksa status container: sudo docker ps"
log "Untuk melihat log PostgreSQL: sudo docker logs postgres_db"
log "Untuk melihat log Redis: sudo docker logs redis_cache"
log "Container dikonfigurasi untuk restart otomatis saat sistem di-reboot."
log ""
log "PENTING: Jika Anda baru saja menginstal Docker, Anda mungkin perlu keluar dan masuk kembali (atau me-reboot) agar pengguna Anda dapat menjalankan perintah 'docker' tanpa 'sudo'."
log "Ingat untuk mengkonfigurasi firewall Anda (misalnya, ufw, firewalld) untuk mengizinkan koneksi masuk ke port $PG_PORT dan $REDIS_PORT jika diakses secara eksternal."