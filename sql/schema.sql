-- ==========================================================
-- vp_newspaper: Esquema de Banco de Dados
-- ==========================================================

CREATE TABLE IF NOT EXISTS `newspaper_texts` (
    `page` VARCHAR(50) NOT NULL,
    `general` LONGTEXT NOT NULL,
    PRIMARY KEY (`page`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `newspaper_company` (
    `id` INT NOT NULL,
    `workers` LONGTEXT NULL,
    `transactions` LONGTEXT NULL,
    `balance` INT NOT NULL DEFAULT 5000,
    `newspaperPrice` INT NOT NULL DEFAULT 10,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `newspaper_boxes` (
    `id` INT AUTO_INCREMENT NOT NULL,
    `coords` VARCHAR(255) NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `stock` INT NOT NULL DEFAULT 15,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vp_newspaper_copies` (
    `id` INT AUTO_INCREMENT NOT NULL,
    `serial` VARCHAR(64) NOT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `newspaper_id` INT NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_serial` (`serial`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed inicial de páginas caso estejam vazias
INSERT IGNORE INTO `newspaper_texts` (`page`, `general`) VALUES
('page1', '[]'),
('page2', '[]'),
('page3', '[]'),
('page4', '[]'),
('page5', '[]');

-- Seed inicial da empresa Weazel News
INSERT IGNORE INTO `newspaper_company` (`id`, `workers`, `transactions`, `balance`, `newspaperPrice`) VALUES
(1, '[]', '[]', 5000, 10);
