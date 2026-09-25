-- ============================================================================
-- Migration 006: Collectibles, PSA Grading, Field Leads & Paperboy Records
-- ============================================================================

CREATE TABLE IF NOT EXISTS `vp_cards_shelf` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `card_id` VARCHAR(50) NOT NULL,
    `rarity` VARCHAR(20) NOT NULL DEFAULT 'basic',
    `serial` VARCHAR(64) DEFAULT NULL,
    `grade` INT NOT NULL DEFAULT 0,
    `discovered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_cards_citizen` (`citizenid`),
    INDEX `idx_cards_card_id` (`card_id`),
    UNIQUE KEY `uk_citizen_card_serial` (`citizenid`, `card_id`, `serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vp_leads` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `lead_id` VARCHAR(64) NOT NULL UNIQUE,
    `citizenid` VARCHAR(50) NOT NULL,
    `author_name` VARCHAR(100) NOT NULL DEFAULT 'Repórter',
    `spot_type` VARCHAR(50) NOT NULL DEFAULT 'interview',
    `headline_seed` VARCHAR(255) NOT NULL,
    `notes` TEXT DEFAULT NULL,
    `used` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_leads_citizen` (`citizenid`),
    INDEX `idx_leads_used` (`used`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vp_paperboy_stats` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `deliveries_count` INT NOT NULL DEFAULT 0,
    `total_earned` INT NOT NULL DEFAULT 0,
    `route_date` DATE NOT NULL,
    INDEX `idx_paperboy_citizen` (`citizenid`),
    UNIQUE KEY `uk_paperboy_daily` (`citizenid`, `route_date`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
