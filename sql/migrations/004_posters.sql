-- ============================================================
-- Migration 004: Tabela de Cartazes e Posters no Mundo
-- ============================================================

CREATE TABLE IF NOT EXISTS `newspaper_posters` (
    `id` INT AUTO_INCREMENT NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `title` VARCHAR(100) NOT NULL DEFAULT 'Poster',
    `url` TEXT NOT NULL,
    `coords` VARCHAR(255) NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `width` FLOAT NOT NULL DEFAULT 0.7,
    `height` FLOAT NOT NULL DEFAULT 1.0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    PRIMARY KEY (`id`),
    INDEX `idx_posters_expires` (`expires_at`),
    INDEX `idx_posters_citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
