# Docker Setup Guide for Endpoint Monitoring

Complete step-by-step guide to run this project using Docker on Windows.

## Prerequisites

### 1. Install Docker Desktop for Windows
- Download from [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Install Docker Desktop with WSL 2 backend (recommended for Windows)
- Ensure Docker Desktop is running
- Verify installation: `docker --version` and `docker-compose --version`

**Important:** You do NOT need to install MySQL, ClickHouse, Kafka, Redis, or Ruby separately. Docker handles all these dependencies automatically.

### 2. Install Git (if not already installed)
- Download from [git-scm.com](https://git-scm.com/)

### 3. Clone the Repository
```bash
git clone <repository-url>
cd endpoint_monitoring
```

## Docker Architecture

This setup includes the following services:

- **MySQL 8.0.43** (Primary Database) - Port 3308
- **MySQL 5.7** (Legacy Database) - Port 3306
- **ClickHouse** (Analytics Database) - Port 8123
- **Zookeeper** (Kafka dependency) - Port 2181
- **Kafka** (Message Queue) - Port 9092
- **Redis** (Cache & Job Queue) - Port 6379
- **Rails App** (Main Application) - Port 3000
- **Sidekiq** (Background Jobs)

## Setup Steps

### Step 1: Create MySQL Configuration File (Optional)

Create a custom MySQL configuration for better performance:

```bash
# Create config directory if it doesn't exist
mkdir -p config

# Create MySQL 8.0 configuration
cat > config/mysql-primary.cnf << 'EOF'
[mysqld]
default-authentication-plugin=mysql_native_password
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=200
innodb_buffer_pool_size=256M
EOF
```

### Step 2: Build and Start All Services

```bash
# Build the Docker images
docker-compose build

# Start all services in detached mode
docker-compose up -d

# View logs for all services
docker-compose logs -f

# View logs for specific service
docker-compose logs -f app
docker-compose logs -f mysql-primary
```

### Step 3: Initialize Databases

```bash
# Enter the Rails app container
docker-compose exec app bash

# Inside the container, run database setup
bundle exec rails db:create
bundle exec rails db:migrate
bundle exec rails db:create:clickhouse
bundle exec rails db:migrate:clickhouse

# Exit the container
exit
```

Or run directly without entering the container:

```bash
# Create and migrate MySQL databases
docker-compose exec app bundle exec rails db:create
docker-compose exec app bundle exec rails db:migrate

# Create and migrate ClickHouse database
docker-compose exec app bundle exec rails db:create:clickhouse
docker-compose exec app bundle exec rails db:migrate:clickhouse
```

### Step 4: Verify Services are Running

```bash
# Check all containers status
docker-compose ps

# Test MySQL 8.0 connection
docker-compose exec mysql-primary mysql -u adminuser -pRoot@123 -e "SHOW DATABASES;"

# Test MySQL 5.7 connection
docker-compose exec mysql-legacy mysql -u root -pRoot@123 -e "SHOW DATABASES;"

# Test ClickHouse connection
docker-compose exec clickhouse clickhouse-client --query "SELECT 1"

# Test Redis connection
docker-compose exec redis redis-cli ping

# Test Kafka topics
docker-compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list
```

### Step 5: Access the Application

- **Rails Application**: http://localhost:3000
- **Swagger API Documentation**: http://localhost:3000/api-docs
- **Rails Console**: `docker-compose exec app bundle exec rails console`

## Common Docker Commands

### Starting and Stopping Services

```bash
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Stop and remove all volumes (deletes data)
docker-compose down -v

# Restart specific service
docker-compose restart app
docker-compose restart sidekiq

# Restart all services
docker-compose restart
```

### Viewing Logs

```bash
# View logs for all services
docker-compose logs -f

# View logs for specific service
docker-compose logs -f app
docker-compose logs -f