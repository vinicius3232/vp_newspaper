-- ==========================================================
-- vp_newspaper: Printing Press & Paper Supply
-- ==========================================================

-- Pegar folhas de papel em branco
RegisterNetEvent('vp_newspaper:server:getBlankPaper', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- Checagem de distância física
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - Config.General.Coords.getPaperCoord) > 4.0 then return end

    local itemName = Config.General.emptyNewpsaperItemName
    local amount = 20

    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, itemName)
        if count and count >= 60 then
            NotifyPlayer(src, _U('alreadyHaveMaxPapers'), 'error')
            return
        end
        exports.ox_inventory:AddItem(src, itemName, amount)
    elseif QBCore then
        local item = player.Functions.GetItemByName(itemName)
        if item and item.amount >= 60 then
            NotifyPlayer(src, _U('alreadyHaveMaxPapers'), 'error')
            return
        end
        player.Functions.AddItem(itemName, amount)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'add')
    end

    NotifyPlayer(src, _U('getEmptyPapers'), 'success')
end)

-- Imprimir caixas de jornais na prensa gráfica
RegisterNetEvent('vp_newspaper:server:printNewspapers', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- Checagem de distância física
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - Config.General.Coords.printerCoord) > 4.0 then return end

    local paperItem = Config.General.emptyNewpsaperItemName
    local boxItem = Config.General.restockBoxesItemName
    local requiredPaper = 5

    -- Verifica posse de papel
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

    -- Fail-Closed: Remove o papel primeiro
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
        NotifyPlayer(src, _U('noItemErrorPrinter'), 'error')
        return
    end

    -- Entrega a caixa de jornais prontos para distribuição
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:AddItem(src, boxItem, 1)
    elseif QBCore then
        player.Functions.AddItem(boxItem, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[boxItem], 'add')
    end

    NotifyPlayer(src, 'Tiragem de jornais impressa com sucesso!', 'success')

    local pName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    SendDiscordLog('Tiragem de Jornais Impressa', ('O repórter **%s** imprimiu uma caixa de jornais para distribuição.'):format(pName), 1752220)
end)
