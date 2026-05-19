CREATE DATABASE IF NOT EXISTS prontooss CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS prontooss_legacy_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS 'adminuser'@'%' IDENTIFIED BY 'Root@123';
GRANT ALL PRIVILEGES ON prontooss.* TO 'adminuser'@'%';
GRANT ALL PRIVILEGES ON prontooss_legacy_test.* TO 'adminuser'@'%';

FLUSH PRIVILEGES;

