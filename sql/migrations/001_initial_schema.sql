-- ============================================================
-- Migration 001: Esquema Base com Versionamento Otimista (OCC)
-- ============================================================

CREATE TABLE IF NOT EXISTS `newspaper_texts` (
    `page` VARCHAR(50) NOT NULL,
    `general` LONGTEXT NOT NULL,
    `revision` INT UNSIGNED NOT NULL DEFAULT 1,
    `updated_by` VARCHAR(64) NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`page`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `newspaper_company` (
    `id` INT NOT NULL,
    `workers` LONGTEXT NULL,
    `balance` INT NOT NULL DEFAULT 5000,
    `newspaperPrice` INT NOT NULL DEFAULT 10,
    `version` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    CONSTRAINT `chk_company_balance_positive` CHECK (`balance` >= 0),
    CONSTRAINT `chk_newspaper_price_positive` CHECK (`newspaperPrice` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `newspaper_boxes` (
    `id` INT AUTO_INCREMENT NOT NULL,
    `coords` VARCHAR(255) NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `stock` INT NOT NULL DEFAULT 15,
    `max_stock` INT NOT NULL DEFAULT 20,
    `version` INT UNSIGNED NOT NULL DEFAULT 1,
    PRIMARY KEY (`id`),
    CONSTRAINT `chk_box_stock_positive` CHECK (`stock` >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seeds de páginas iniciais
INSERT IGNORE INTO `newspaper_texts` (`page`, `general`, `revision`) VALUES
('page1', '[]', 1),
('page2', '[]', 1),
('page3', '[]', 1),
('page4', '[]', 1),
('page5', '[]', 1);

-- Seed de empresa inicial
INSERT IGNORE INTO `newspaper_company` (`id`, `workers`, `balance`, `newspaperPrice`, `version`) VALUES
(1, '[]', 5000, 10, 1);
