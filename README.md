# dockersetup.sh

🚀 **Automated PostgreSQL & Redis Deployment Script with Docker**

`dockersetup.sh` is a comprehensive and user-friendly shell script designed to automate the process of installing Docker (if not already present) and deploying a PostgreSQL and Redis database environment using Docker Compose. The script is compatible with a wide range of Linux distributions (including Ubuntu, Fedora, Arch, CentOS, and openSUSE) and ensures that both databases will automatically start when your system reboots.

---

### ✨ Key Features:
- **Automatic Docker Installation**: Smart OS detection and seamless Docker installation if not detected.
- **PostgreSQL & Redis Deployment**: Deploys pre-configured PostgreSQL and Redis containers.
- **Persistent Data**: Uses Docker volumes to ensure your database data is safe and persists across container restarts or removals.
- **Automatic Startup**: The `restart: always` configuration ensures your databases come back online automatically after a system reboot.
- **Cross-Distribution Compatible**: Designed to work across major Linux distributions.
- **Single-Command Execution**: Easy deployment with just a single command line.
- **Secure Password Handling**: Interactively prompts for passwords if they are not provided as environment variables.

---

### 📝 Prerequisites:
- A supported Linux operating system (Ubuntu, Debian, Linux Mint, Fedora, CentOS/RHEL/AlmaLinux/Rocky, Arch Linux, openSUSE).
- `sudo` access (root privileges).
- An internet connection.

---

### 🚀 How to Use:
You can run this script with a single command from your terminal.

#### 1. Set Passwords (Optional but Recommended):
It is highly recommended to set the PostgreSQL and Redis passwords as environment variables before running the script for security and to avoid interactive prompts. Replace the example values with your own strong, unique passwords.

```bash
export PG_PASSWORD="a_very_strong_postgres_password"
export REDIS_PASSWORD="a_very_strong_redis_password" # Leave empty if you don't want a password for Redis

# You can also customize other variables if needed:
# export PG_VERSION="16"
# export REDIS_VERSION="7"
# export PG_DATA_PATH="/mnt/my_volume/pg_data"
# export REDIS_DATA_PATH="/mnt/my_volume/redis_data"
# export PG_PORT="5433"
# export REDIS_PORT="6380"
# export PG_USER="myuser"
# export PG_DB="mydb"
```

#### 2. Run the Script:
Copy and paste the command below into your terminal and press Enter.

```bash
wget -qO dockersetup.sh https://raw.githubusercontent.com/MrPinguiiin/dockersetup/main/dockersetup.sh && chmod +x dockersetup.sh && sudo ./dockersetup.sh
```

**IMPORTANT**: Make sure you have reviewed the script's contents before running it with root privileges.

---

### ⚙️ Default Configuration:
| Service      | Configuration    | Default Value             | Environment Variable |
|--------------|------------------|---------------------------|----------------------|
| **PostgreSQL** | Version          | `16`                      | `PG_VERSION`         |
|              | Host Port        | `5432`                    | `PG_PORT`            |
|              | User             | `dockeruser` (prompts)    | `PG_USER`            |
|              | Database         | `mydatabase` (prompts)    | `PG_DB`              |
|              | Host Data Path   | `/data/postgresql_data`   | `PG_DATA_PATH`       |
| **Redis**      | Version          | `7-alpine`                | `REDIS_VERSION`      |
|              | Host Port        | `6379`                    | `REDIS_PORT`         |
|              | Host Data Path   | `/data/redis_data`        | `REDIS_DATA_PATH`    |

---

### 👀 After Deployment:

- **Verify Containers**:
  ```bash
  sudo docker ps
  ```
  You should see `postgres_db` and `redis_cache` running.

- **View PostgreSQL Logs**:
  ```bash
  sudo docker logs postgres_db
  ```

- **View Redis Logs**:
  ```bash
  sudo docker logs redis_cache
  ```

- **Update Containers**: If you want to use a new version of an image:
  ```bash
  cd <directory_where_script_was_executed>
  sudo docker compose pull
  sudo docker compose up -d
  ```

- **Stop & Remove Containers**:
  ```bash
  cd <directory_where_script_was_executed>
  sudo docker compose down
  ```
  *(This will not delete the data in the host volumes).*

---

### ⚠️ Important Notes:
- **Firewall Security**: This script does **NOT** configure your system's firewall (like `ufw` or `firewalld`). If you plan to access PostgreSQL or Redis from outside the machine they are deployed on, you **MUST** open the relevant ports (e.g., 5432 and 6379) in your firewall.
- **Docker Access Without Sudo**: If Docker was just installed, you might need to **log out and log back in (or reboot)** your system for your user to be able to run `docker` commands without `sudo`. The script automatically adds your user to the `docker` group.
- **Data Persistence**: Your database data is stored in the host directories you specified (default: `/data/postgresql_data` and `/data/redis_data`). **Do not delete these directories if you want to keep your data!** 