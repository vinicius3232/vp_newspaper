-- ==========================================================
-- vp_newspaper: Hardened Company Vault, CAS & Staff Auth
-- ==========================================================

---Obtém dados consolidados da empresa Weazel News
---@param cb function(data: table)
function GetCompanyData(cb)
    MySQL.query('SELECT * FROM `newspaper_company` WHERE `id` = 1 LIMIT 1', {}, function(results)
        if results and results[1] then
            local data = results[1]
            data.workers = json.decode(data.workers) or {}
            data.transactions = Ledger.GetRecent(20)
            cb(data)
        else
            local defaultData = {
                id = 1,
                workers = {},
                transactions = {},
                balance = 5000,
                newspaperPrice = 10,
                version = 1
            }
            cb(defaultData)
        end
    end)
end

-- ==========================================================
-- Sincronização e Callbacks do Painel de Gestão (NUI)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:requestManagementData', function()
    local src = source

    -- 1. Rate Limit (Tier: FAST)
    if not Security.CheckRateLimit(src, 'request_management', 'FAST') then return end

    -- 2. Distância Física (Max 2.0m)
    local okDist = Security.ValidateDistance(src, Config.General.Coords.managementCoord, 'MANAGEMENT')
    if not okDist then
        NotifyPlayer(src, 'Você está distante do balcão de gestão.', 'error')
        return
    end

    -- 3. Autorização (Apenas funcionários da redação ou gerentes)
    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Acesso restrito à equipe da Weazel News.', 'error')
        return
    end

    GetCompanyData(function(data)
        TriggerClientEvent('vp_newspaper:client:openManagement', src, data)
    end)
end)

-- ==========================================================
-- Atualização Financeira & Preço com CAS Atômico
-- ==========================================================

RegisterNetEvent('databaseupdate', function(actionType, amount)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: CRITICAL)
    if not Security.CheckRateLimit(src, 'company_action', 'CRITICAL') then
        NotifyPlayer(src, 'Muitas requisições. Aguarde um instante.', 'error')
        return
    end

    -- 2. Distância Física
    local okDist = Security.ValidateDistance(src, Config.General.Coords.managementCoord, 'MANAGEMENT')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar no escritório da redação para realizar operações financeiras.', 'error')
        return
    end

    amount = tonumber(amount) or 0

    -- ======================================================
    -- Ação: Alterar Preço do Jornal
    -- ======================================================
    if actionType == 'newspaperPrice' then
        local isBoss = Security.IsAuthorized(src, Config.General.jobName, Config.General.jobBossGrade, true)
        if not isBoss then
            NotifyPlayer(src, 'Apenas o Diretor da redação pode alterar a tabela de preços!', 'error')
            return
        end

        if amount <= 0 or amount > Config.General.maxNewspaperPrice then
            NotifyPlayer(src, _U('newspaperPriceUpdateError'), 'error')
            return
        end

        MySQL.query('UPDATE `newspaper_company` SET `newspaperPrice` = ?, `version` = `version` + 1 WHERE `id` = 1', { amount }, function()
            NotifyPlayer(src, _U('newspaperPriceUpdated', amount), 'success')
            GetCompanyData(function(data)
                TriggerClientEvent('vp_newspaper:client:updateManagerData', src, data)
            end)
        end)

    -- ======================================================
    -- Ação: Depositar Fundos no Cofre
    -- ======================================================
    elseif actionType == 'addFunds' then
        if amount <= 0 or amount > 500000 then
            NotifyPlayer(src, 'Valor de depósito inválido.', 'error')
            return
        end

        local pBank = GetPlayerMoney(src, 'bank')
        if pBank < amount then
            NotifyPlayer(src, _U('addFundsError'), 'error')
            return
        end

        local opId = Operations.New('vault_deposit', src, cid, 'company_vault', amount, { amount = amount })
        Operations.Transition(opId, 'PROCESSING')

        -- Remove dinheiro do jogador (Fail-Closed)
        local debited = RemovePlayerMoney(src, 'bank', amount, 'weazel_news_deposit')
        if not debited then
            Operations.Transition(opId, 'ABORTED', 'player_debit_failed')
            NotifyPlayer(src, _U('addFundsError'), 'error')
            return
        end

        -- Incrementa saldo no cofre
        local compBefore = MySQL.single.await('SELECT `balance` FROM `newspaper_company` WHERE `id` = 1')
        local prevBal = compBefore and compBefore.balance or 0
        local newBal = prevBal + amount

        MySQL.query.await('UPDATE `newspaper_company` SET `balance` = `balance` + ?, `version` = `version` + 1 WHERE `id` = 1', { amount })
        Ledger.Record(opId, cid, 'deposit', amount, prevBal, newBal)
        Operations.Transition(opId, 'COMMITTED')

        NotifyPlayer(src, _U('fundsAdded', amount), 'success')
        GetCompanyData(function(data)
            TriggerClientEvent('vp_newspaper:client:updateManagerData', src, data)
        end)

    -- ======================================================
    -- Ação: Sacar Fundos do Cofre (CAS Atômico)
    -- ======================================================
    elseif actionType == 'withdrawFunds' then
        local isBoss = Security.IsAuthorized(src, Config.General.jobName, Config.General.jobBossGrade, true)
        if not isBoss then
            NotifyPlayer(src, 'Apenas a diretoria possui autorização para efetuar saques do cofre!', 'error')
            return
        end

        if amount <= 0 or amount > 500000 then
            NotifyPlayer(src, 'Valor de saque inválido.', 'error')
            return
        end

        local opId = Operations.New('vault_withdraw', src, cid, 'company_vault', amount, { amount = amount })
        Operations.Transition(opId, 'PROCESSING')

        -- CAS Atômico: Deduz do cofre SOMENTE se o saldo for maior ou igual ao montante solicitado
        local updateResult = MySQL.query.await([[
            UPDATE `newspaper_company`
            SET `balance` = `balance` - ?, `version` = `version` + 1
            WHERE `id` = 1 AND `balance` >= ?
        ]], { amount, amount })

        if not updateResult or updateResult.affectedRows == 0 then
            Operations.Transition(opId, 'ABORTED', 'insufficient_vault_balance')
            NotifyPlayer(src, 'Saldo do cofre insuficiente para realizar este saque!', 'error')
            return
        end

        -- Adiciona dinheiro ao jogador
        local credited = AddPlayerMoney(src, 'bank', amount, 'weazel_news_withdraw')
        if not credited then
            -- Compensação caso a concessão de dinheiro falhe
            MySQL.query.await('UPDATE `newspaper_company` SET `balance` = `balance` + ? WHERE `id` = 1', { amount })
            Operations.Transition(opId, 'COMPENSATED', 'credit_to_player_failed')
            NotifyPlayer(src, 'Falha ao creditar fundos em sua conta. Operação estornada.', 'error')
            return
        end

        local compRow = MySQL.single.await('SELECT `balance` FROM `newspaper_company` WHERE `id` = 1')
        local newBal = compRow and compRow.balance or 0
        local prevBal = newBal + amount

        Ledger.Record(opId, cid, 'withdraw', -amount, prevBal, newBal)
        Operations.Transition(opId, 'COMMITTED')

        NotifyPlayer(src, _U('fundsWithdrawn', amount), 'success')
        GetCompanyData(function(data)
            TriggerClientEvent('vp_newspaper:client:updateManagerData', src, data)
        end)
    end
end)

-- ==========================================================
-- Contratação e Gestão de Pessoal com Verificação de Cargo
-- ==========================================================

RegisterNetEvent('nproblem_newspaper_iseal', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end

    -- Verificação de Cargo: Apenas Gerência pode contratar
    local isBoss = Security.IsAuthorized(src, Config.General.jobName, Config.General.jobBossGrade, true)
    if not isBoss then
        NotifyPlayer(src, 'Apenas diretores podem admitir novos funcionários!', 'error')
        return
    end

    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then
        NotifyPlayer(src, 'Cidadão não encontrado.', 'error')
        return
    end

    local tCid = targetPlayer.PlayerData.citizenid
    local tName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

    GetCompanyData(function(comp)
        local workers = comp.workers or {}
        for _, w in ipairs(workers) do
            if w.id == tCid then
                NotifyPlayer(src, 'Este cidadão já é funcionário da redação!', 'error')
                return
            end
        end

        table.insert(workers, {
            id = tCid,
            name = tName,
            time = os.date('%H:%M %d/%m'),
            pos = 'Distribuidor'
        })

        MySQL.query('UPDATE `newspaper_company` SET `workers` = ?, `version` = `version` + 1 WHERE `id` = 1', { json.encode(workers) }, function()
            NotifyPlayer(src, _U('hireSuccess'), 'success')
            comp.workers = workers
            TriggerClientEvent('vp_newspaper:client:updateManagerData', src, comp)
        end)
    end)
end)

RegisterNetEvent('nproblem_newspaper_fireupdown', function(workerCid, actionType)
    local src = source
    if not workerCid or not actionType then return end

    -- Verificação de Cargo: Apenas Gerência pode demitir/promover
    local isBoss = Security.IsAuthorized(src, Config.General.jobName, Config.General.jobBossGrade, true)
    if not isBoss then
        NotifyPlayer(src, 'Apenas diretores podem gerenciar o quadro de funcionários!', 'error')
        return
    end

    GetCompanyData(function(comp)
        local workers = comp.workers or {}
        local updated = {}

        for _, w in ipairs(workers) do
            if w.id == workerCid then
                if actionType == 'fire' then
                    -- omitido da lista
                elseif actionType == 'up' then
                    w.pos = 'Editor Chefe'
                    table.insert(updated, w)
                elseif actionType == 'down' then
                    w.pos = 'Distribuidor'
                    table.insert(updated, w)
                else
                    table.insert(updated, w)
                end
            else
                table.insert(updated, w)
            end
        end

        MySQL.query('UPDATE `newspaper_company` SET `workers` = ?, `version` = `version` + 1 WHERE `id` = 1', { json.encode(updated) }, function()
            if actionType == 'fire' then
                NotifyPlayer(src, _U('fireSuccess'), 'success')
            else
                NotifyPlayer(src, _U('rankUpdated'), 'success')
            end
            comp.workers = updated
            TriggerClientEvent('vp_newspaper:client:updateManagerData', src, comp)
        end)
    end)
end)
