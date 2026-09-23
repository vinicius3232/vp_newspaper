-- ==========================================================
-- vp_newspaper: Database Migrations Runner (oxmysql)
-- ==========================================================

local migrations = {
    'sql/migrations/001_initial_schema.sql',
    'sql/migrations/002_operations_and_ledger.sql',
    'sql/migrations/003_editor_sessions.sql',
}

local function RunMigrations()
    local resName = GetCurrentResourceName()
    print('^2[vp_newspaper] Verificando migrações de banco de dados...^7')

    for _, migrationPath in ipairs(migrations) do
        local sqlContent = LoadResourceFile(resName, migrationPath)
        if sqlContent and #sqlContent > 0 then
            -- Divide por ponto e vírgula ignorando linhas vazias
            for statement in string.gmatch(sqlContent, "([^;]+);") do
                local clean = statement:gsub("^%s+", ""):gsub("%s+$", "")
                if #clean > 0 and not clean:match("^%-%-") then
                    MySQL.query.await(clean)
                end
            end
        else
            print(('^1[vp_newspaper] Falha ao carregar arquivo de migração: %s^7'):format(migrationPath))
        end
    end

    print('^2[vp_newspaper] Todas as migrações foram executadas com sucesso.^7')
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(500)
    end
    RunMigrations()
end)
