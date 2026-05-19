CREATE DATABASE IF NOT EXISTS endpoint_monitoring CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS endpoint_monitoring_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'adminuser'@'%' IDENTIFIED BY 'Root@123';
GRANT ALL PRIVILEGES ON endpoint_monitoring.* TO 'adminuser'@'%';
GRANT ALL PRIVILEGES ON endpoint_monitoring_test.* TO 'adminuser'@'%';

FLUSH PRIVILEGES;

