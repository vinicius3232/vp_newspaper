-- ==========================================================
-- vp_newspaper: Database Migrations Runner (oxmysql)
-- ==========================================================

local migrations = {
    'sql/migrations/001_initial_schema.sql',
    'sql/migrations/002_operations_and_ledger.sql',
    'sql/migrations/003_editor_sessions.sql',
    'sql/migrations/004_posters.sql',
    'sql/migrations/005_speakers_system.sql',
    'sql/migrations/006_collectibles_and_leads.sql',
    'sql/migrations/007_custom_cards.sql',
}

DatabaseReady = false

local function RunMigrations()
    local resName = GetCurrentResourceName()
    print('^2[vp_newspaper] Verificando migrações de banco de dados...^7')

    for _, migrationPath in ipairs(migrations) do
        local sqlContent = LoadResourceFile(resName, migrationPath)
        if sqlContent and #sqlContent > 0 then
            -- Divide por ponto e vírgula ignorando linhas vazias
            for statement in string.gmatch(sqlContent, "([^;]+);") do
                local clean = statement:gsub("^%s+", ""):gsub("%s+$", "")
                -- Remove linhas de comentário SQL (-- ...)
                local lines = {}
                for line in clean:gmatch("[^\r\n]+") do
                    local trimmed = line:gsub("^%s+", "")
                    if not trimmed:match("^%-%-") then
                        table.insert(lines, line)
                    end
                end
                local executable = table.concat(lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
                if #executable > 0 then
                    MySQL.query.await(executable)
                end
            end
        else
            print(('^1[vp_newspaper] Falha ao carregar arquivo de migração: %s^7'):format(migrationPath))
        end
    end

    DatabaseReady = true
    print('^2[vp_newspaper] Todas as migrações foram executadas com sucesso.^7')
    TriggerEvent('vp_newspaper:server:migrationsComplete')
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(500)
    end
    RunMigrations()
end)
