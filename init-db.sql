-- =============================================================================
-- SQL Script  : init-db.sql
-- Description : Khoi tao database springboot_db va user quan tri spring-admin
-- Author      : Trần Trí Dương (duongtran1702)
-- Student ID  : duongtran1702 | Email: duong170226@gmail.com
-- Course      : IT209 - Session 07 - Bai tap 3
-- =============================================================================

-- 1. Tao co so du lieu springboot_db voi ma hoa ho tro day du UTF-8
CREATE DATABASE IF NOT EXISTS springboot_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- 2. Tao nguoi dung chuyen trach spring-admin voi mat khau bao mat manh
-- Cho phep ket noi tu localhost (noi ung dung Spring Boot thuc thi)
CREATE USER IF NOT EXISTS 'spring-admin'@'localhost'
  IDENTIFIED BY 'SpringSecure@123';

-- (Tuy chon) Cho phep ket noi tu dai IP noi bo 127.0.0.1
CREATE USER IF NOT EXISTS 'spring-admin'@'127.0.0.1'
  IDENTIFIED BY 'SpringSecure@123';

-- 3. Cap toan quyen (ALL PRIVILEGES) tren database springboot_db cho spring-admin
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'localhost';
GRANT ALL PRIVILEGES ON springboot_db.* TO 'spring-admin'@'127.0.0.1';

-- 4. Nap lai bang dac quyen (Privilege Tables)
FLUSH PRIVILEGES;

-- 5. Kiem tra va tao bang mau kiem tra ket noi (Health Check Table)
USE springboot_db;

CREATE TABLE IF NOT EXISTS system_health (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    component_name VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO system_health (component_name, status)
VALUES ('Spring Boot 8082 Application', 'ONLINE'),
       ('MySQL Database Connection Pool', 'HEALTHY');

-- Hien thi xac nhan
SELECT User, Host FROM mysql.user WHERE User = 'spring-admin';
SHOW GRANTS FOR 'spring-admin'@'localhost';
