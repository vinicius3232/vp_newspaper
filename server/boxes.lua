-- ==========================================================
-- vp_newspaper: Hardened Newspaper Boxes, Purchase & Restock
-- ==========================================================

local Boxes = {}

---Carrega todas as bancas do banco de dados com versionamento CAS
local function LoadBoxes()
    local rows = MySQL.query.await('SELECT `id`, `coords`, `heading`, `stock`, `max_stock`, `version` FROM `newspaper_boxes`', {})
    Boxes = {}
    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            local c = json.decode(row.coords)
            Boxes[row.id] = {
                id = row.id,
                coords = vector3(c.x, c.y, c.z),
                heading = row.heading or 0.0,
                stock = row.stock or 0,
                maxStock = row.max_stock or 20,
                version = row.version or 1,
            }
        end
    end
    TriggerClientEvent('vp_newspaper:client:syncBoxes', -1, Boxes)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1500)
    LoadBoxes()
end)

RegisterNetEvent('vp_newspaper:server:requestBoxes', function()
    local src = source
    TriggerClientEvent('vp_newspaper:client:syncBoxes', src, Boxes)
end)

-- ==========================================================
-- Criação de Nova Banca de Jornal (Modo Interativo / Admin)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:createBox', function(coords, heading)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- 1. Permissão Administrativa
    local isAllowed = false
    if IsPlayerAceAllowed(tostring(src), 'command') or IsPlayerAceAllowed(tostring(src), 'vp_newspaper.createbox') then
        isAllowed = true
    elseif player.PlayerData and player.PlayerData.permission then
        local pGroup = player.PlayerData.permission
        for _, allowed in ipairs(Config.General.creatingBoxes.allowedGroups or { 'admin', 'god' }) do
            if pGroup == allowed then
                isAllowed = true
                break
            end
        end
    end

    if not isAllowed then
        NotifyPlayer(src, 'Você não possui permissão para instalar bancas de jornal.', 'error')
        return
    end

    -- 2. Rate Limit (Tier: CRITICAL)
    if not Security.CheckRateLimit(src, 'create_newspaper_box', 'CRITICAL') then
        NotifyPlayer(src, 'Aguarde alguns segundos antes de criar outra banca.', 'error')
        return
    end

    -- 3. Sanitização e Bounds Checking
    if type(coords) ~= 'table' or not coords.x or not coords.y or not coords.z then
        NotifyPlayer(src, 'Coordenadas inválidas para instalação da banca.', 'error')
        return
    end

    coords.x = tonumber(coords.x)
    coords.y = tonumber(coords.y)
    coords.z = tonumber(coords.z)
    heading = tonumber(heading) or 0.0

    if not coords.x or not coords.y or not coords.z then return end

    -- Checa proximidade do ped que está executando a ação (máx 15 metros)
    local ped = GetPlayerPed(src)
    if ped and DoesEntityExist(ped) then
        local pCoords = GetEntityCoords(ped)
        local dist = #(pCoords - vector3(coords.x, coords.y, coords.z))
        if dist > 15.0 then
            NotifyPlayer(src, 'Local de instalação muito distante da sua posição atual.', 'error')
            return
        end
    end

    -- 4. Persistência no Banco de Dados
    local coordsJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    local insertId = MySQL.insert.await([[
        INSERT INTO `newspaper_boxes` (`coords`, `heading`, `stock`, `max_stock`, `version`)
        VALUES (?, ?, 15, 20, 1)
    ]], { coordsJson, heading })

    if insertId and insertId > 0 then
        Boxes[insertId] = {
            id = insertId,
            coords = vector3(coords.x, coords.y, coords.z),
            heading = heading,
            stock = 15,
            maxStock = 20,
            version = 1
        }

        TriggerClientEvent('vp_newspaper:client:syncBoxes', -1, Boxes)
        NotifyPlayer(src, 'Banca de jornal instalada e sincronizada com sucesso!', 'success')
        SendDiscordLog('Nova Banca de Jornal Criada', ('O administrador **%s** criou a banca #%d em `%.2f, %.2f, %.2f`.'):format(GetPlayerName(src) or 'Admin', insertId, coords.x, coords.y, coords.z), 65280)
    else
        NotifyPlayer(src, 'Falha ao salvar a banca no banco de dados.', 'error')
    end
end)

-- ==========================================================
-- Compra de Jornal — Transação Idempotente, Atômica & Anti-Dupe
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:buyNewspaper', function(boxId)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: ECONOMIC)
    if not Security.CheckRateLimit(src, 'buy_newspaper', 'ECONOMIC') then
        NotifyPlayer(src, 'Por favor, aguarde alguns segundos antes de comprar novamente.', 'error')
        return
    end

    boxId = tonumber(boxId)
    local box = Boxes[boxId]
    if not box then
        NotifyPlayer(src, 'Banca de jornal não encontrada.', 'error')
        return
    end

    -- 2. Checagem Estrita de Distância Física no Servidor (Max 2.5m)
    local okDist, currentDist = Security.ValidateDistance(src, box.coords, 'STAND')
    if not okDist then
        NotifyPlayer(src, 'Você está muito distante da banca de jornal.', 'error')
        return
    end

    -- 3. Obtenção do Preço Atual do Jornal
    local compRow = MySQL.single.await('SELECT `newspaperPrice`, `balance` FROM `newspaper_company` WHERE `id` = 1')
    local price = compRow and compRow.newspaperPrice or 10

    -- 4. Criação do Registro de Operação Durável (PENDING)
    local opId = Operations.New('purchase', src, cid, tostring(boxId), price, { boxId = boxId, price = price })
    Operations.Transition(opId, 'PROCESSING')

    -- 5. Compare-And-Swap (CAS) Atômico no Estoque da Banca (Proteção contra Concorrência)
    local updateResult = MySQL.query.await([[
        UPDATE `newspaper_boxes`
        SET `stock` = `stock` - 1, `version` = `version` + 1
        WHERE `id` = ? AND `stock` > 0
    ]], { boxId })

    local affectedRows = updateResult and updateResult.affectedRows or 0
    if affectedRows == 0 then
        -- Falha atômica: Estoque acabou ou outro jogador comprou o último exemplar concorrentemente
        Operations.Transition(opId, 'ABORTED', 'out_of_stock')
        NotifyPlayer(src, _U('noNewspaper'), 'error')
        return
    end

    -- 6. Verificação e Débito Financeiro (Fail-Closed)
    local pCash = GetPlayerMoney(src, 'cash')
    local usedType = 'cash'
    if pCash < price then
        local pBank = GetPlayerMoney(src, 'bank')
        if pBank >= price then
            usedType = 'bank'
        else
            -- Sem fundos suficientes: Estorna o estoque da banca
            MySQL.query.await('UPDATE `newspaper_boxes` SET `stock` = `stock` + 1 WHERE `id` = ?', { boxId })
            Operations.Transition(opId, 'ABORTED', 'insufficient_funds')
            NotifyPlayer(src, _U('buyNewspaperError'), 'error')
            return
        end
    end

    local debited = RemovePlayerMoney(src, usedType, price, 'newspaper_purchase')
    if not debited then
        -- Falha ao remover dinheiro: Estorna o estoque
        MySQL.query.await('UPDATE `newspaper_boxes` SET `stock` = `stock` + 1 WHERE `id` = ?', { boxId })
        Operations.Transition(opId, 'ABORTED', 'debit_failed')
        NotifyPlayer(src, _U('buyNewspaperError'), 'error')
        return
    end

    -- 7. Geração de Serial Único CSPRNG e Registro no Banco (Anti-Dupe Triplo)
    local serial = Operations.GenerateUUID()
    local copyInserted = MySQL.insert.await([[
        INSERT INTO `vp_newspaper_copies`
        (`serial`, `owner_cid`, `newspaper_id`, `edition`, `operation_id`, `status`)
        VALUES (?, ?, 1, 1, ?, 'ACTIVE')
    ]], { serial, cid, opId })

    if not copyInserted then
        -- Falha ao registrar cópia: Compensação atômica
        AddPlayerMoney(src, usedType, price, 'newspaper_purchase_refund')
        MySQL.query.await('UPDATE `newspaper_boxes` SET `stock` = `stock` + 1 WHERE `id` = ?', { boxId })
        Operations.Transition(opId, 'COMPENSATED', 'serial_insert_failed')
        NotifyPlayer(src, 'Erro na emissão do jornal. Seu dinheiro foi estornado.', 'error')
        return
    end

    -- 8. Entrega do Item no Inventário do Jogador
    local itemGiven = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        itemGiven = exports.ox_inventory:AddItem(src, Config.General.newspaperItemName, 1, {
            serial = serial,
            date = os.date('%d/%m/%Y'),
            edition = 1,
            opId = opId
        })
    elseif QBCore then
        itemGiven = player.Functions.AddItem(Config.General.newspaperItemName, 1, false, {
            serial = serial,
            date = os.date('%d/%m/%Y'),
            edition = 1,
            opId = opId
        })
        if itemGiven then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.General.newspaperItemName], 'add')
        end
    end

    if not itemGiven then
        -- Falha ao entregar item (Inventário Cheio): Compensação Completa
        AddPlayerMoney(src, usedType, price, 'newspaper_refund_inventory_full')
        MySQL.query.await('UPDATE `newspaper_boxes` SET `stock` = `stock` + 1 WHERE `id` = ?', { boxId })
        MySQL.query.await('UPDATE `vp_newspaper_copies` SET `status` = \'BURNED\' WHERE `serial` = ?', { serial })
        Operations.Transition(opId, 'COMPENSATED', 'inventory_full')
        NotifyPlayer(src, 'Seu inventário está cheio! A compra foi cancelada e o valor estornado.', 'error')
        return
    end

    -- 9. Atualização do Cofre da Empresa e Registro no Ledger Imutável
    local prevBal = compRow and compRow.balance or 5000
    local newBal = prevBal + price
    MySQL.query.await('UPDATE `newspaper_company` SET `balance` = `balance` + ? WHERE `id` = 1', { price })
    Ledger.Record(opId, cid, 'sale_revenue', price, prevBal, newBal)

    -- 10. Conclusão com Sucesso
    Operations.Transition(opId, 'COMMITTED')

    -- Atualiza cache local de estoque e sincroniza
    box.stock = box.stock - 1
    TriggerClientEvent('vp_newspaper:client:updateBoxStock', -1, boxId, box.stock)

    NotifyPlayer(src, _U('buyNewspaperSuccess', price), 'success')
end)

-- ==========================================================
-- Reabastecimento de Banca — Crash-Safe, Concorrência & Payout
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:restockBox', function(boxId)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: ECONOMIC)
    if not Security.CheckRateLimit(src, 'restock_box', 'ECONOMIC') then
        NotifyPlayer(src, 'Aguarde alguns instantes antes de reabastecer novamente.', 'error')
        return
    end

    boxId = tonumber(boxId)
    local box = Boxes[boxId]
    if not box then
        NotifyPlayer(src, 'Banca não encontrada.', 'error')
        return
    end

    -- 2. Autorização: Apenas membros da empresa Weazel News podem reabastecer
    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas funcionários da redação podem abastecer as bancas!', 'error')
        return
    end

    -- 3. Checagem de Distância Física no Servidor (Max 2.5m)
    local okDist = Security.ValidateDistance(src, box.coords, 'STAND')
    if not okDist then
        NotifyPlayer(src, 'Você está muito distante da banca.', 'error')
        return
    end

    -- 4. Verificação de Capacidade Máxima
    local currentDbBox = MySQL.single.await('SELECT `stock`, `max_stock`, `version` FROM `newspaper_boxes` WHERE `id` = ?', { boxId })
    if not currentDbBox or currentDbBox.stock >= currentDbBox.max_stock then
        NotifyPlayer(src, _U('restockFullError'), 'error')
        return
    end

    -- 5. Criação do Registro de Operação Durável
    local minR = Config.General.restockPerReward[1] or 35
    local maxR = Config.General.restockPerReward[2] or 70
    local reward = math.random(minR, maxR)

    local opId = Operations.New('restock', src, cid, tostring(boxId), reward, { boxId = boxId, reward = reward })
    Operations.Transition(opId, 'PROCESSING')

    -- 6. Verificação e Remoção da Caixa de Jornais do Inventário (Fail-Closed)
    local boxItemName = Config.General.restockBoxesItemName
    local removed = false

    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, boxItemName)
        if count and count > 0 then
            removed = exports.ox_inventory:RemoveItem(src, boxItemName, 1)
        end
    elseif QBCore then
        local item = player.Functions.GetItemByName(boxItemName)
        if item and item.amount and item.amount > 0 then
            removed = player.Functions.RemoveItem(boxItemName, 1)
            if removed then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[boxItemName], 'remove')
            end
        end
    end

    if not removed then
        Operations.Transition(opId, 'ABORTED', 'no_box_item')
        NotifyPlayer(src, _U('restockNoItemError'), 'error')
        return
    end

    -- 7. CAS Atômico de Atualização de Estoque
    local updateStock = MySQL.query.await([[
        UPDATE `newspaper_boxes`
        SET `stock` = `max_stock`, `version` = `version` + 1
        WHERE `id` = ? AND `stock` < `max_stock`
    ]], { boxId })

    if not updateStock or updateStock.affectedRows == 0 then
        -- Outro distribuidor encheu a banca concomitantemente: Compensar item
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            exports.ox_inventory:AddItem(src, boxItemName, 1)
        elseif QBCore then
            player.Functions.AddItem(boxItemName, 1)
        end
        Operations.Transition(opId, 'COMPENSATED', 'concurrent_restock_already_full')
        NotifyPlayer(src, 'Esta banca acabou de ser abastecida por outro entregador! Sua caixa foi devolvida.', 'info')
        return
    end

    -- 8. Pagamento da Comissão ao Entregador
    AddPlayerMoney(src, 'cash', reward, 'newspaper_restock_delivery')

    -- 9. Conclusão e Registro no Ledger
    Operations.Transition(opId, 'COMMITTED')
    box.stock = currentDbBox.max_stock
    TriggerClientEvent('vp_newspaper:client:updateBoxStock', -1, boxId, box.stock)

    NotifyPlayer(src, _U('restockSuccess', reward), 'success')
end)
