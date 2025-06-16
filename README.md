# dockersetup.sh

🚀 **Skrip Deployment Otomatis PostgreSQL & Redis dengan Docker**

`dockersetup.sh` adalah skrip shell komprehensif dan mudah digunakan, dirancang untuk mengotomatisasi proses instalasi Docker (jika belum ada) dan mendeploy lingkungan database PostgreSQL serta Redis menggunakan Docker Compose. Skrip ini kompatibel dengan berbagai distribusi Linux (termasuk Ubuntu, Fedora, Arch, CentOS, dan openSUSE) dan memastikan kedua database secara otomatis akan menyala saat sistem Anda di-reboot.

---

### ✨ Fitur Utama:
- **Instalasi Docker Otomatis**: Deteksi OS cerdas dan instalasi Docker yang mulus jika tidak terdeteksi.
- **Deployment PostgreSQL & Redis**: Menyebarkan container PostgreSQL dan Redis yang telah dikonfigurasi sebelumnya.
- **Persistent Data**: Menggunakan volume Docker untuk memastikan data database Anda aman dan tidak hilang saat container di-restart atau dihapus.
- **Automatic Startup**: Konfigurasi `restart: always` memastikan database Anda online kembali secara otomatis setelah reboot sistem.
- **Cross-Distribution Compatible**: Dirancang untuk bekerja di berbagai distribusi Linux utama.
- **Single-Command Execution**: Kemudahan deployment hanya dengan satu baris perintah.
- **Penanganan Kata Sandi Aman**: Meminta kata sandi secara interaktif jika tidak disediakan sebagai variabel lingkungan.

---

### 📝 Prasyarat:
- Sistem operasi Linux yang didukung (Ubuntu, Debian, Linux Mint, Fedora, CentOS/RHEL/AlmaLinux/Rocky, Arch Linux, openSUSE).
- Akses `sudo` (hak akses root).
- Koneksi internet.

---

### 🚀 Cara Menggunakan:
Anda bisa menjalankan skrip ini hanya dengan satu perintah dari terminal Anda.

#### 1. Atur Kata Sandi (Opsional tapi Direkomendasikan):
Sangat disarankan untuk mengatur kata sandi PostgreSQL dan Redis sebagai variabel lingkungan sebelum menjalankan skrip untuk keamanan dan menghindari prompt interaktif. Ganti nilai contoh dengan kata sandi yang kuat dan unik.

```bash
export PG_PASSWORD="kata_sandi_postgres_yang_sangat_kuat"
export REDIS_PASSWORD="kata_sandi_redis_yang_sangat_kuat" # Biarkan kosong jika Redis tidak ingin pakai kata sandi

# Anda juga bisa menyesuaikan variabel lain jika diperlukan:
# export PG_VERSION="16"
# export REDIS_VERSION="7"
# export PG_DATA_PATH="/mnt/my_volume/pg_data"
# export REDIS_DATA_PATH="/mnt/my_volume/redis_data"
# export PG_PORT="5433"
# export REDIS_PORT="6380"
# export PG_USER="myuser"
# export PG_DB="mydb"
```

#### 2. Jalankan Skrip:
Salin dan tempelkan perintah di bawah ini ke terminal Anda dan tekan Enter.

```bash
wget -qO dockersetup.sh https://raw.githubusercontent.com/your-github-username/your-repo-name/main/dockersetup.sh && chmod +x dockersetup.sh && sudo ./dockersetup.sh
```
**PENTING**: Ganti `https://raw.githubusercontent.com/your-github-username/your-repo-name/main/dockersetup.sh` dengan URL mentah (raw URL) yang sebenarnya dari file `dockersetup.sh` di repositori GitHub Anda.

---

### ⚙️ Konfigurasi Default:
| Service      | Konfigurasi            | Nilai Default                  | Variabel Lingkungan |
|--------------|------------------------|--------------------------------|---------------------|
| **PostgreSQL** | Versi                  | `16`                           | `PG_VERSION`        |
|              | Port Host              | `5432`                         | `PG_PORT`           |
|              | User                   | `dockeruser`                   | `PG_USER`           |
|              | Database               | `mydatabase`                   | `PG_DB`             |
|              | Jalur Data Host        | `/data/postgresql_data`        | `PG_DATA_PATH`      |
| **Redis**      | Versi                  | `7-alpine`                     | `REDIS_VERSION`     |
|              | Port Host              | `6379`                         | `REDIS_PORT`        |
|              | Jalur Data Host        | `/data/redis_data`             | `REDIS_DATA_PATH`   |

---

### 👀 Setelah Deployment Selesai:

- **Verifikasi Container**:
  ```bash
  sudo docker ps
  ```
  Anda akan melihat `postgres_db` dan `redis_cache` berjalan.

- **Lihat Log PostgreSQL**:
  ```bash
  sudo docker logs postgres_db
  ```

- **Lihat Log Redis**:
  ```bash
  sudo docker logs redis_cache
  ```

- **Perbarui Container**: Jika ada versi baru image yang ingin Anda gunakan:
  ```bash
  cd <direktori_tempat_skrip_dieksekusi>
  sudo docker compose pull
  sudo docker compose up -d
  ```

- **Hentikan & Hapus Container**:
  ```bash
  cd <direktori_tempat_skrip_dieksekusi>
  sudo docker compose down
  ```
  *(Ini tidak akan menghapus data di volume host).*

---

### ⚠️ Catatan Penting:
- **Keamanan Firewall**: Skrip ini **TIDAK** mengkonfigurasi firewall sistem Anda (seperti `ufw` atau `firewalld`). Jika Anda berencana mengakses PostgreSQL atau Redis dari luar mesin tempat mereka di-deploy, Anda **HARUS** membuka port yang relevan (misalnya 5432 dan 6379) di firewall Anda.
- **Hak Akses Docker Tanpa Sudo**: Jika Docker baru saja diinstal, Anda mungkin perlu **keluar dan masuk kembali (atau me-reboot)** ke sistem Anda agar pengguna Anda dapat menjalankan perintah `docker` tanpa `sudo`. Skrip secara otomatis menambahkan Anda ke grup `docker`.
- **Data Persistence**: Data database Anda disimpan di direktori host yang Anda tentukan (default: `/data/postgresql_data` dan `/data/redis_data`). **Jangan hapus direktori ini jika Anda ingin menyimpan data Anda!** 