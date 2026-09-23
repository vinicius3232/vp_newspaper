-- ==========================================================
-- vp_newspaper: Company Management, Funds & Workers
-- ==========================================================

---Obtém dados consolidados da empresa Weazel News
---@param cb function(data: table)
function GetCompanyData(cb)
    MySQL.query('SELECT * FROM `newspaper_company` WHERE `id` = 1 LIMIT 1', {}, function(results)
        if results and results[1] then
            local data = results[1]
            data.workers = json.decode(data.workers) or {}
            data.transactions = json.decode(data.transactions) or {}
            cb(data)
        else
            local defaultData = {
                id = 1,
                workers = {},
                transactions = {},
                balance = 5000,
                newspaperPrice = 10
            }
            cb(defaultData)
        end
    end)
end

---Adiciona receita à empresa (ex: venda de jornais nas bancas)
---@param amount number
function AddCompanyRevenue(amount)
    if not amount or amount <= 0 then return end
    GetCompanyData(function(comp)
        local newBalance = comp.balance + amount
        local txs = comp.transactions or {}
        table.insert(txs, 1, {
            type = 'Deposit',
            amount = amount,
            date = os.date('%H:%M %d/%m'),
            timestamp = os.time()
        })
        if #txs > 20 then table.remove(txs) end

        MySQL.query('UPDATE `newspaper_company` SET `balance` = ?, `transactions` = ? WHERE `id` = 1', {
            newBalance, json.encode(txs)
        })
    end)
end

-- ==========================================================
-- Sincronização e Callbacks do Painel de Gestão (NUI)
-- ==========================================================

-- Callback legado/compatível para abertura da gestão
if QBCore then
    QBCore.Functions.CreateCallback('nproblem_newspaper_dataal', function(source, cb)
        GetCompanyData(function(data)
            cb({ data })
        end)
    end)
end

-- Evento para atualizar a NUI de gestão
RegisterNetEvent('vp_newspaper:server:requestManagementData', function()
    local src = source
    GetCompanyData(function(data)
        TriggerClientEvent('vp_newspaper:client:openManagement', src, data)
    end)
end)

-- ==========================================================
-- Atualização Financeira & Preço (databaseupdate)
-- ==========================================================

RegisterNetEvent('databaseupdate', function(actionType, amount)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    amount = tonumber(amount) or 0

    if actionType == 'newspaperPrice' then
        if amount <= 0 or amount > Config.General.maxNewspaperPrice then
            NotifyPlayer(src, _U('newspaperPriceUpdateError'), 'error')
            return
        end

        MySQL.query('UPDATE `newspaper_company` SET `newspaperPrice` = ? WHERE `id` = 1', { amount }, function()
            NotifyPlayer(src, _U('newspaperPriceUpdated', amount), 'success')
            GetCompanyData(function(data)
                TriggerClientEvent('vp_newspaper:client:updateManagerData', src, data)
            end)
        end)

    elseif actionType == 'addFunds' then
        if amount <= 0 then return end
        
        -- Checa e remove dinheiro do jogador (banco ou cash)
        local pMoney = GetPlayerMoney(src, 'bank')
        if pMoney < amount then
            NotifyPlayer(src, _U('addFundsError'), 'error')
            return
        end

        if RemovePlayerMoney(src, 'bank', amount, 'weazel_news_deposit') then
            GetCompanyData(function(comp)
                local newBal = comp.balance + amount
                local txs = comp.transactions or {}
                table.insert(txs, 1, {
                    type = 'Deposit',
                    amount = amount,
                    date = os.date('%H:%M %d/%m'),
                    timestamp = os.time()
                })
                if #txs > 20 then table.remove(txs) end

                MySQL.query('UPDATE `newspaper_company` SET `balance` = ?, `transactions` = ? WHERE `id` = 1', {
                    newBal, json.encode(txs)
                }, function()
                    NotifyPlayer(src, _U('fundsAdded', amount), 'success')
                    comp.balance = newBal
                    comp.transactions = txs
                    TriggerClientEvent('vp_newspaper:client:updateManagerData', src, comp)
                end)
            end)
        else
            NotifyPlayer(src, _U('addFundsError'), 'error')
        end

    elseif actionType == 'withdrawFunds' then
        if amount <= 0 then return end

        GetCompanyData(function(comp)
            if comp.balance < amount then
                NotifyPlayer(src, 'Saldo da empresa insuficiente para este saque!', 'error')
                return
            end

            local newBal = comp.balance - amount
            local txs = comp.transactions or {}
            table.insert(txs, 1, {
                type = 'Withdraw',
                amount = amount,
                date = os.date('%H:%M %d/%m'),
                timestamp = os.time()
            })
            if #txs > 20 then table.remove(txs) end

            MySQL.query('UPDATE `newspaper_company` SET `balance` = ?, `transactions` = ? WHERE `id` = 1', {
                newBal, json.encode(txs)
            }, function()
                AddPlayerMoney(src, 'bank', amount, 'weazel_news_withdraw')
                NotifyPlayer(src, _U('fundsWithdrawn', amount), 'success')
                comp.balance = newBal
                comp.transactions = txs
                TriggerClientEvent('vp_newspaper:client:updateManagerData', src, comp)
            end)
        end)
    end
end)

-- ==========================================================
-- Contratação, Demissão e Promoção de Funcionários
-- ==========================================================

RegisterNetEvent('nproblem_newspaper_iseal', function(targetId)
    local src = source
    targetId = tonumber(targetId)
    if not targetId then return end

    local targetPlayer = GetPlayer(targetId)
    if not targetPlayer then return end

    local tCid = targetPlayer.PlayerData.citizenid
    local tName = targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname

    GetCompanyData(function(comp)
        local workers = comp.workers or {}
        -- Verifica se já trabalha
        for _, w in ipairs(workers) do
            if w.id == tCid then
                NotifyPlayer(src, 'Este cidadão já é funcionário da empresa!', 'error')
                return
            end
        end

        table.insert(workers, {
            id = tCid,
            name = tName,
            time = os.date('%H:%M %d/%m'),
            pos = 'Distribuidor'
        })

        MySQL.query('UPDATE `newspaper_company` SET `workers` = ? WHERE `id` = 1', { json.encode(workers) }, function()
            NotifyPlayer(src, _U('hireSuccess'), 'success')
            comp.workers = workers
            TriggerClientEvent('vp_newspaper:client:updateManagerData', src, comp)
        end)
    end)
end)

RegisterNetEvent('nproblem_newspaper_fireupdown', function(workerCid, actionType)
    local src = source
    if not workerCid or not actionType then return end

    GetCompanyData(function(comp)
        local workers = comp.workers or {}
        local updated = {}

        for _, w in ipairs(workers) do
            if w.id == workerCid then
                if actionType == 'fire' then
                    -- não adiciona (demitido)
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

        MySQL.query('UPDATE `newspaper_company` SET `workers` = ? WHERE `id` = 1', { json.encode(updated) }, function()
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
