-- ==========================================================
-- vp_newspaper: Hardened Printing Press & Paper Supply
-- ==========================================================

-- Pegar folhas de papel em branco
RegisterNetEvent('vp_newspaper:server:getBlankPaper', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- 1. Rate Limit (Tier: ECONOMIC)
    if not Security.CheckRateLimit(src, 'get_blank_paper', 'ECONOMIC') then
        NotifyPlayer(src, 'Aguarde antes de coletar mais papel.', 'error')
        return
    end

    -- 2. Autorização (Apenas funcionários da redação)
    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas funcionários da Weazel News podem acessar o almoxarifado de papel.', 'error')
        return
    end

    -- 3. Checagem de Distância Física no Servidor (Max 2.5m)
    local okDist = Security.ValidateDistance(src, Config.General.Coords.getPaperCoord, 'PAPER')
    if not okDist then
        NotifyPlayer(src, 'Você está distante do depósito de bobinas de papel.', 'error')
        return
    end

    local itemName = Config.General.emptyNewpsaperItemName
    local amount = 20

    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, itemName)
        if count and count >= 60 then
            NotifyPlayer(src, _U('alreadyHaveMaxPapers'), 'error')
            return
        end
        local added = exports.ox_inventory:AddItem(src, itemName, amount)
        if not added then
            NotifyPlayer(src, 'Seu inventário não possui espaço para transportar mais bobinas de papel!', 'error')
            return
        end
    elseif QBCore then
        local item = player.Functions.GetItemByName(itemName)
        if item and item.amount >= 60 then
            NotifyPlayer(src, _U('alreadyHaveMaxPapers'), 'error')
            return
        end
        local added = player.Functions.AddItem(itemName, amount)
        if not added then
            NotifyPlayer(src, 'Inventário cheio!', 'error')
            return
        end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
    end

    NotifyPlayer(src, _U('getEmptyPapers'), 'success')
end)

-- Imprimir caixas de jornais na prensa gráfica com compensação atômica
RegisterNetEvent('vp_newspaper:server:printNewspapers', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: ECONOMIC)
    if not Security.CheckRateLimit(src, 'print_newspaper', 'ECONOMIC') then
        NotifyPlayer(src, 'Aguarde o ciclo da prensa gráfica concluir.', 'error')
        return
    end

    -- 2. Autorização
    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas membros da equipe jornalística podem operar a prensa gráfica!', 'error')
        return
    end

    -- 3. Checagem de Distância Física no Servidor (Max 2.5m)
    local okDist = Security.ValidateDistance(src, Config.General.Coords.printerCoord, 'PRINTING')
    if not okDist then
        NotifyPlayer(src, 'Você está muito distante da prensa gráfica.', 'error')
        return
    end

    local paperItem = Config.General.emptyNewpsaperItemName
    local boxItem = Config.General.restockBoxesItemName
    local requiredPaper = 5

    -- 4. Verificação de Posse de Insumos
    local hasPaper = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, paperItem)
        hasPaper = (count and count >= requiredPaper)
    elseif QBCore then
        local item = player.Functions.GetItemByName(paperItem)
        hasPaper = (item and item.amount and item.amount >= requiredPaper)
    end

    if not hasPaper then
        NotifyPlayer(src, _U('noItemErrorPrinter'), 'error')
        return
    end

    -- 5. Criação de Operação Durável
    local opId = Operations.New('print', src, cid, 'printer', requiredPaper, { paper = requiredPaper })
    Operations.Transition(opId, 'PROCESSING')

    -- 6. Consumo dos Insumos de Papel (Fail-Closed)
    local removed = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        removed = exports.ox_inventory:RemoveItem(src, paperItem, requiredPaper)
    elseif QBCore then
        removed = player.Functions.RemoveItem(paperItem, requiredPaper)
        if removed then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[paperItem], 'remove')
        end
    end

    if not removed then
        Operations.Transition(opId, 'ABORTED', 'paper_removal_failed')
        NotifyPlayer(src, _U('noItemErrorPrinter'), 'error')
        return
    end

    -- 7. Entrega da Caixa de Jornais Impressos (com rollback/compensação se falhar)
    local boxAdded = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        boxAdded = exports.ox_inventory:AddItem(src, boxItem, 1)
    elseif QBCore then
        boxAdded = player.Functions.AddItem(boxItem, 1)
        if boxAdded then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[boxItem], 'add')
        end
    end

    if not boxAdded then
        -- Compensação Atômica: Devolve os 5 papéis ao jogador
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            exports.ox_inventory:AddItem(src, paperItem, requiredPaper)
        elseif QBCore then
            player.Functions.AddItem(paperItem, requiredPaper)
        end
        Operations.Transition(opId, 'COMPENSATED', 'inventory_full_paper_refunded')
        NotifyPlayer(src, 'Falha ao receber a caixa de jornais (inventário cheio/pesado). O papel foi devolvido.', 'error')
        return
    end

    -- 8. Conclusão da Operação
    Operations.Transition(opId, 'COMMITTED')
    NotifyPlayer(src, 'Tiragem de jornais impressa com sucesso!', 'success')

    local pName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    SendDiscordLog('Tiragem de Jornais Impressa', ('O repórter **%s** imprimiu uma caixa de jornais para distribuição.'):format(pName), 1752220)
end)

-- Imprimir exemplar individual de leitura (1 folha de papel = 1 jornal legível)
RegisterNetEvent('vp_newspaper:server:printSingleNewspaper', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if not Security.CheckRateLimit(src, 'print_single_newspaper', 'FAST') then
        NotifyPlayer(src, 'Aguarde um instante antes de imprimir novamente.', 'error')
        return
    end

    local isDebug = Config.General and (Config.General.debugs or Config.General.allowTestCommands)
    local isAuth = isDebug or Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas membros da equipe jornalística podem operar a impressora!', 'error')
        return
    end

    local okDist = isDebug or Security.ValidateDistance(src, Config.General.Coords.printerCoord, 'PRINTING')
    if not okDist then
        NotifyPlayer(src, 'Você está distante da impressora.', 'error')
        return
    end

    local paperItem = Config.General.emptyNewpsaperItemName or 'empty_newspaper'
    local newspaperItem = Config.General.newspaperItemName or 'newspaper'

    local hasPaper = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, paperItem)
        hasPaper = (count and count >= 1)
    elseif QBCore then
        local item = player.Functions.GetItemByName(paperItem)
        hasPaper = (item and item.amount and item.amount >= 1)
    end

    if not hasPaper then
        NotifyPlayer(src, _U('noItemErrorPrinter'), 'error')
        return
    end

    local removed = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        removed = exports.ox_inventory:RemoveItem(src, paperItem, 1)
    elseif QBCore then
        removed = player.Functions.RemoveItem(paperItem, 1)
        if removed then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[paperItem], 'remove')
        end
    end

    if not removed then
        NotifyPlayer(src, _U('noItemErrorPrinter'), 'error')
        return
    end

    local serial = Operations.GenerateUUID()
    local added = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        added = exports.ox_inventory:AddItem(src, newspaperItem, 1, { serial = serial, date = os.date('%d/%m/%Y') })
    elseif QBCore then
        added = player.Functions.AddItem(newspaperItem, 1, false, { serial = serial, date = os.date('%d/%m/%Y') })
        if added then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[newspaperItem], 'add')
        end
    end

    if not added then
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            exports.ox_inventory:AddItem(src, paperItem, 1)
        elseif QBCore then
            player.Functions.AddItem(paperItem, 1)
        end
        NotifyPlayer(src, 'Inventário cheio para receber o jornal. A folha foi devolvida.', 'error')
        return
    end

    NotifyPlayer(src, 'Exemplar impresso com sucesso! Use o jornal no inventário para ler.', 'success')
end)

-- Desempacotar caixa de jornais em 5 exemplares individuais de leitura
RegisterNetEvent('vp_newspaper:server:unpackNewspaperBox', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if not Security.CheckRateLimit(src, 'unpack_box', 'FAST') then
        NotifyPlayer(src, 'Aguarde um momento.', 'error')
        return
    end

    local boxItem = Config.General.restockBoxesItemName or 'newspaperbox'
    local newspaperItem = Config.General.newspaperItemName or 'newspaper'

    local hasBox = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, boxItem)
        hasBox = (count and count >= 1)
    elseif QBCore then
        local item = player.Functions.GetItemByName(boxItem)
        hasBox = (item and item.amount and item.amount >= 1)
    end

    if not hasBox then
        NotifyPlayer(src, 'Você não possui uma caixa de jornais para abrir!', 'error')
        return
    end

    local removed = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        removed = exports.ox_inventory:RemoveItem(src, boxItem, 1)
    elseif QBCore then
        removed = player.Functions.RemoveItem(boxItem, 1)
        if removed then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[boxItem], 'remove')
        end
    end

    if not removed then
        NotifyPlayer(src, 'Não foi possível abrir a caixa.', 'error')
        return
    end

    local countGiven = 5
    local added = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        added = exports.ox_inventory:AddItem(src, newspaperItem, countGiven)
    elseif QBCore then
        added = player.Functions.AddItem(newspaperItem, countGiven)
        if added then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[newspaperItem], 'add')
        end
    end

    if not added then
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            exports.ox_inventory:AddItem(src, boxItem, 1)
        elseif QBCore then
            player.Functions.AddItem(boxItem, 1)
        end
        NotifyPlayer(src, 'Inventário sem espaço suficiente para 5 jornais. A caixa foi mantida.', 'error')
        return
    end

    NotifyPlayer(src, 'Você abriu a caixa e extraiu 5 jornais impressos prontos para leitura!', 'success')
end)
