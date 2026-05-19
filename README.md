# Endpoint Monitoring - Setup Guide

Complete step-by-step guide to run this project on a new Windows laptop.

## Prerequisites

### 1. Ruby Environment
- *Ruby Version*: 3.4.5
- *Installation Options*:
  - Download from [rubyinstaller.org](https://rubyinstaller.org/) (recommended for Windows)
  - Or use [rbenv](https://github.com/rbenv/rbenv) with [ruby-build](https://github.com/rbenv/ruby-build)
  - Or use [rvm](https://rvm.io/)

### 2. Database Systems

#### MySQL 8.0.43 (Primary Database)
- Download from [MySQL Community Server](https://dev.mysql.com/downloads/mysql/)
- Install MySQL 8.0.43 or compatible version
- Configure to run on *port 3308*
- Create databases and users (see Database Setup section)

#### MySQL 5.7 (Legacy Database)
- Download from [MySQL Archive](https://downloads.mysql.com/archives/community/)
- Install MySQL 5.7
- Configure to run on *port 3306*
- Create databases and users (see Database Setup section)

#### ClickHouse (Analytics Database)
- Download from [ClickHouse website](https://clickhouse.com/)
- Install ClickHouse server
- Configure to run on *port 8123*
- Default database: default

### 3. Message Queue & Cache

#### Apache Kafka
- Download from [Kafka website](https://kafka.apache.org/downloads)
- Install and start Kafka
- Configure to run on *port 9092*
- Required topics will be created automatically:
  - endpoint-monitoring
  - internet-quality

#### Redis
- Download from [Redis website](https://redis.io/download)
- Or use [Memurai](https://www.memurai.com/) for Windows
- Configure to run on *port 6379*

### 4. Additional Tools
- *Git*: [git-scm.com](https://git-scm.com/)
- *Bundler*: Comes with Ruby, or install via gem install bundler
- *Node.js & Yarn* (for asset compilation if needed): [nodejs.org](https://nodejs.org/)

## Installation Steps

### Step 1: Clone the Repository
bash
git clone <repository-url>
cd endpoint_monitoring


### Step 2: Install Ruby Dependencies
bash
# Install bundler if not already installed
gem install bundler

# Install all gems
bundle install


### Step 3: Configure Environment Variables
Copy the .env file and update it with your local configuration:

bash
# The .env file already exists with default values
# Update the following based on your setup:


*Key Environment Variables to Update:*

bash
# MySQL 8.0 (Primary) - Port 3308
database_dev_primary=endpoint_monitoring
username_dev_primary=adminuser
password_dev_primary=Root@123
database_dev_url=127.0.0.1

# MySQL 5.7 (Legacy) - Port 3306
database_dev_legacy=prontooss
username_dev_legacy=root
password_dev_legacy=Root@123

# ClickHouse
CLICKHOUSE_HOST=127.0.0.1
CLICKHOUSE_PORT=8123
CLICKHOUSE_DB=default
CLICKHOUSE_USER=
CLICKHOUSE_PASSWORD=

# Kafka
KAFKA_BROKERS=localhost:9092
KAFKA_ROUTER_METRICS_TOPIC=endpoint-monitoring
KAFKA_ROUTER_METRICS_GROUP=endpoint-monitoring-group
KAFKA_INTERNET_QUALITY_TOPIC=internet-quality
KAFKA_INTERNET_QUALITY_GROUP=internet-quality-group

# Redis
REDIS_URL=redis://localhost:6379/0

# Rails
RAILS_ENV=development
SWAGGER_URL=http://localhost:3000
CLOUD_CONTROLLER_BASE_URL=http://localhost:3000/api/v1


### Step 4: Database Setup

#### 4.1 Create MySQL Databases and Users

*For MySQL 8.0 (Port 3308):*
sql
-- Connect to MySQL 8.0 on port 3308
mysql -h 127.0.0.1 -P 3308 -u root -p

-- Create database
CREATE DATABASE endpoint_monitoring CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create user (if not exists)
CREATE USER 'adminuser'@'%' IDENTIFIED BY 'Root@123';
GRANT ALL PRIVILEGES ON endpoint_monitoring.* TO 'adminuser'@'%';
FLUSH PRIVILEGES;


*For MySQL 5.7 (Port 3306):*
sql
-- Connect to MySQL 5.7 on port 3306
mysql -h 127.0.0.1 -P 3306 -u root -p

-- Create database
CREATE DATABASE prontooss CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant privileges (assuming root user exists)
-- If using different user, create and grant similarly


#### 4.2 Create ClickHouse Database
sql
-- Connect to ClickHouse
clickhouse-client

-- Create database (if not exists)
CREATE DATABASE IF NOT EXISTS default;


#### 4.3 Run Database Migrations
bash
# Setup primary MySQL database
bundle exec rails db:create
bundle exec rails db:migrate

# Setup ClickHouse database
bundle exec rails db:create:clickhouse
bundle exec rails db:migrate:clickhouse


### Step 5: Start Required Services

Make sure all services are running before starting the Rails application:

bash
# Start MySQL 8.0 (port 3308)
# Start MySQL 5.7 (port 3306)
# Start ClickHouse (port 8123)
# Start Kafka (port 9092)
# Start Redis (port 6379)


*Starting Kafka (example):*
bash
# Start Zookeeper
bin/zookeeper-server-start.sh config/zookeeper.properties

# Start Kafka
bin/kafka-server-start.sh config/server.properties


*Starting Redis (example):*
bash
redis-server


### Step 6: Start the Rails Application

bash
# Start the Rails server
bundle exec rails server


The application will be available at: http://localhost:3000

### Step 7: Start Background Workers (Sidekiq)

In a separate terminal:

bash
# Start Sidekiq for background job processing
bundle exec sidekiq


### Step 8: Access API Documentation

Swagger UI is available at: http://localhost:3000/api-docs

## Running Tests

bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/path/to/spec.rb


## Project Structure


endpoint_monitoring/
├── app/                    # Main application code
├── config/                 # Configuration files
├── db/                     # Database files
│   ├── migrate/           # MySQL migrations
│   └── migrate_clickhouse/ # ClickHouse migrations
├── spec/                   # Test files
├── lib/                    # Library files
└── public/                 # Public assets


## Key Technologies

- *Rails 8.0.2* - Web framework
- *MySQL 8.0.43* - Primary database
- *MySQL 5.7* - Legacy database
- *ClickHouse* - Analytics database
- *Kafka* - Message queue
- *Redis* - Cache and job queue
- *Sidekiq* - Background job processing
- *RSpec* - Testing framework
- *Swagger* - API documentation

## Troubleshooting

### Port Conflicts
If you encounter port conflicts, update the ports in:
- .env file
- config/database.yml
- Service configuration files

### Database Connection Issues
bash
# Test MySQL connection
mysql -h 127.0.0.1 -P 3308 -u adminuser -p

# Test ClickHouse connection
clickhouse-client --host 127.0.0.1 --port 8123

# Test Redis connection
redis-cli ping


### Kafka Connection Issues
bash
# List Kafka topics
bin/kafka-topics.sh --list --bootstrap-server localhost:9092

# Create topic manually if needed
bin/kafka-topics.sh --create --topic endpoint-monitoring --bootstrap-server localhost:9092


### Bundle Install Issues
bash
# Update bundler
gem update bundler

# Clean and reinstall
bundle clean
bundle install


## Development Workflow

1. Make changes to code
2. Run migrations if needed: bundle exec rails db:migrate
3. Restart Rails server
4. Run tests: bundle exec rspec
5. Check Swagger docs at http://localhost:3000/api-docs

## Additional Notes

- The project uses multiple databases (MySQL 8.0, MySQL 5.7, ClickHouse)
- Kafka is used for real-time data streaming
- Sidekiq processes background jobs
- Redis is used for caching and job queues
- The legacy MySQL 5.7 database is read-only for this application

## Support

For issues or questions, please refer to the project documentation or contact the development team.