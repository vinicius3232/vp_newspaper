-- ============================================================
-- Migration 003: Sessões de Edição e Locks Atômicos
-- ============================================================

CREATE TABLE IF NOT EXISTS `vp_newspaper_editor_sessions` (
    `session_id` VARCHAR(64) NOT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `source_id` INT NOT NULL,
    `acquired_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `last_heartbeat` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`session_id`),
    INDEX `idx_session_owner` (`owner_cid`),
    INDEX `idx_session_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
