-- ==========================================================
-- vp_newspaper: Permanent Speakers & Playback History
-- ==========================================================

CREATE TABLE IF NOT EXISTS `newspaper_permanent_speakers` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `speaker_type` VARCHAR(32) NOT NULL DEFAULT 'retro',
    `coords` LONGTEXT NOT NULL,
    `heading` FLOAT NOT NULL DEFAULT 0.0,
    `volume` FLOAT NOT NULL DEFAULT 0.8,
    `max_range` FLOAT NOT NULL DEFAULT 35.0,
    `name` VARCHAR(64) NOT NULL DEFAULT 'Caixa Permanente',
    `security_mode` VARCHAR(16) NOT NULL DEFAULT 'public',
    `pin_code` VARCHAR(8) NULL DEFAULT NULL,
    `created_by` VARCHAR(64) NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `newspaper_speaker_history` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(64) NOT NULL,
    `url` VARCHAR(512) NOT NULL,
    `title` VARCHAR(128) NOT NULL,
    `is_favorite` TINYINT(1) NOT NULL DEFAULT 0,
    `played_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_speaker_history_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `newspaper_speaker_groups` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(64) NOT NULL,
    `connect_code` VARCHAR(32) NOT NULL UNIQUE,
    `access_code` VARCHAR(32) NOT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
