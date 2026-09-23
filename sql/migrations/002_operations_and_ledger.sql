-- ============================================================
-- Migration 002: Máquina de Estados de Operações, Ledger & Seriais
-- ============================================================

CREATE TABLE IF NOT EXISTS `vp_newspaper_operations` (
    `operation_id` VARCHAR(64) NOT NULL,
    `op_type` VARCHAR(32) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `source_id` INT NOT NULL,
    `target_id` VARCHAR(64) NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `state` ENUM('PENDING','PROCESSING','COMMITTED','COMPENSATING','COMPENSATED','FAILED','MANUAL_REVIEW') NOT NULL DEFAULT 'PENDING',
    `payload` LONGTEXT NULL,
    `error_reason` VARCHAR(255) NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`operation_id`),
    INDEX `idx_op_state` (`state`),
    INDEX `idx_op_cid_type` (`citizenid`, `op_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vp_newspaper_ledger` (
    `transaction_id` INT AUTO_INCREMENT NOT NULL,
    `operation_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `action` VARCHAR(32) NOT NULL,
    `amount` INT NOT NULL,
    `balance_before` INT NOT NULL,
    `balance_after` INT NOT NULL,
    `timestamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`transaction_id`),
    INDEX `idx_ledger_op` (`operation_id`),
    INDEX `idx_ledger_cid` (`citizenid`),
    INDEX `idx_ledger_time` (`timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vp_newspaper_copies` (
    `id` INT AUTO_INCREMENT NOT NULL,
    `serial` VARCHAR(64) NOT NULL,
    `owner_cid` VARCHAR(64) NOT NULL,
    `newspaper_id` INT NOT NULL DEFAULT 1,
    `edition` INT NOT NULL DEFAULT 1,
    `operation_id` VARCHAR(64) NOT NULL,
    `status` ENUM('ACTIVE','BURNED','STOLEN') NOT NULL DEFAULT 'ACTIVE',
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_newspaper_serial` (`serial`),
    INDEX `idx_copies_owner` (`owner_cid`),
    INDEX `idx_copies_op` (`operation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
