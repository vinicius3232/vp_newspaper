-- ============================================================================
-- Migration 007: Dynamic Custom Cards & Living RP Minting Engine
-- ============================================================================

CREATE TABLE IF NOT EXISTS `vp_custom_cards` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `card_id` VARCHAR(64) NOT NULL UNIQUE,
    `rarity` VARCHAR(20) NOT NULL DEFAULT 'basic',
    `title` VARCHAR(100) NOT NULL,
    `description` TEXT NOT NULL,
    `image_url` VARCHAR(512) NOT NULL,
    `set_name` VARCHAR(100) NOT NULL DEFAULT 'Edição Especial Weazel',
    `created_by` VARCHAR(50) NOT NULL,
    `author_name` VARCHAR(100) NOT NULL,
    `is_active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_custom_cards_rarity` (`rarity`, `is_active`),
    INDEX `idx_custom_cards_author` (`created_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
