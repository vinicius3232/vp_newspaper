-- ==========================================================
-- vp_newspaper: Auto-Schema & Database Migrations (oxmysql)
-- ==========================================================

CreateThread(function()
    -- Garante que o oxmysql esteja pronto
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(500)
    end

    local queries = {
        [[
            CREATE TABLE IF NOT EXISTS `newspaper_texts` (
                `page` VARCHAR(50) NOT NULL,
                `general` LONGTEXT NOT NULL,
                PRIMARY KEY (`page`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `newspaper_company` (
                `id` INT NOT NULL,
                `workers` LONGTEXT NULL,
                `transactions` LONGTEXT NULL,
                `balance` INT NOT NULL DEFAULT 5000,
                `newspaperPrice` INT NOT NULL DEFAULT 10,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `newspaper_boxes` (
                `id` INT AUTO_INCREMENT NOT NULL,
                `coords` VARCHAR(255) NOT NULL,
                `heading` FLOAT NOT NULL DEFAULT 0.0,
                `stock` INT NOT NULL DEFAULT 15,
                PRIMARY KEY (`id`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            CREATE TABLE IF NOT EXISTS `vp_newspaper_copies` (
                `id` INT AUTO_INCREMENT NOT NULL,
                `serial` VARCHAR(64) NOT NULL,
                `owner_cid` VARCHAR(64) NOT NULL,
                `newspaper_id` INT NOT NULL DEFAULT 1,
                `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                PRIMARY KEY (`id`),
                UNIQUE KEY `uk_serial` (`serial`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        ]],
        [[
            INSERT IGNORE INTO `newspaper_company` (`id`, `workers`, `transactions`, `balance`, `newspaperPrice`)
            VALUES (1, '[]', '[]', 5000, 10);
        ]],
        [[
            INSERT IGNORE INTO `newspaper_texts` (`page`, `general`) VALUES
            ('page1', '[]'), ('page2', '[]'), ('page3', '[]'), ('page4', '[]'), ('page5', '[]');
        ]]
    }

    for i = 1, #queries do
        MySQL.query.await(queries[i])
    end

    print('^2[vp_newspaper] Tabelas e seeds do banco de dados verificados com sucesso.^7')
end)
