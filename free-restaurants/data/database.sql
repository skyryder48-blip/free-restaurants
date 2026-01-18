-- Free Restaurants Database Schema
-- Run this SQL in your database before starting the resource

-- Restaurant Pricing (custom menu prices)
CREATE TABLE IF NOT EXISTS `restaurant_pricing` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(50) NOT NULL,
    `item_id` VARCHAR(100) NOT NULL,
    `price` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_job_item` (`job`, `item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Restaurant Payroll (custom wage settings)
CREATE TABLE IF NOT EXISTS `restaurant_payroll` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(50) NOT NULL,
    `grade` INT NOT NULL,
    `wage` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_job_grade` (`job`, `grade`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Restaurant Transactions (financial history)
CREATE TABLE IF NOT EXISTS `restaurant_transactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `job` VARCHAR(50) NOT NULL,
    `type` ENUM('deposit', 'withdrawal', 'sale', 'expense', 'stock_order') NOT NULL,
    `amount` INT NOT NULL,
    `description` VARCHAR(255),
    `player_id` VARCHAR(50),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_job` (`job`),
    INDEX `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Stock Orders (pending pickup missions)
CREATE TABLE IF NOT EXISTS `restaurant_stock_orders` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `order_id` VARCHAR(20) NOT NULL UNIQUE,
    `job` VARCHAR(50) NOT NULL,
    `items` JSON NOT NULL,
    `total_cost` INT NOT NULL DEFAULT 0,
    `status` ENUM('pending', 'ready', 'picked_up', 'expired') NOT NULL DEFAULT 'pending',
    `pickup_coords` VARCHAR(100),
    `ordered_by` VARCHAR(50),
    `picked_up_by` VARCHAR(50),
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL,
    INDEX `idx_job_status` (`job`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Player Progression (skill levels)
CREATE TABLE IF NOT EXISTS `restaurant_progression` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `job` VARCHAR(50) NOT NULL,
    `skill` VARCHAR(50) NOT NULL DEFAULT 'cooking',
    `level` INT NOT NULL DEFAULT 1,
    `xp` INT NOT NULL DEFAULT 0,
    `total_xp` INT NOT NULL DEFAULT 0,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_player_job_skill` (`citizenid`, `job`, `skill`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Delivery Orders
CREATE TABLE IF NOT EXISTS `restaurant_deliveries` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `delivery_id` VARCHAR(20) NOT NULL UNIQUE,
    `job` VARCHAR(50) NOT NULL,
    `order_id` VARCHAR(20),
    `items` JSON,
    `destination` VARCHAR(255),
    `destination_coords` VARCHAR(100),
    `status` ENUM('pending', 'assigned', 'picked_up', 'delivered', 'failed', 'expired') NOT NULL DEFAULT 'pending',
    `assigned_to` VARCHAR(50),
    `vehicle_plate` VARCHAR(10),
    `tip_amount` INT DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `completed_at` TIMESTAMP NULL,
    INDEX `idx_job_status` (`job`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
