-- ==========================================================
-- vp_newspaper: Core Server, Framework Bridge & Usables
-- ==========================================================

QBCore = nil

if GetResourceState('qbx_core') == 'started' then
    -- Qbox Core
    print('^2[vp_newspaper] Integrado com QBX Core.^7')
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    print('^2[vp_newspaper] Integrado com QBCore legado/padrão.^7')
end

---Obtém objeto do jogador unificado
---@param src number
---@return table|nil
function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayer(src)
    elseif QBCore then
        return QBCore.Functions.GetPlayer(src)
    end
    return nil
end

---Obtém jogador por CitizenID
---@param cid string
---@return table|nil
function GetPlayerByCitizenId(cid)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayerByCitizenId(cid)
    elseif QBCore then
        return QBCore.Functions.GetPlayerByCitizenId(cid)
    end
    return nil
end

---Verifica saldo do jogador
---@param src number
---@param moneyType string 'cash'|'bank'
---@return number
function GetPlayerMoney(src, moneyType)
    local player = GetPlayer(src)
    if not player then return 0 end
    return player.Functions.GetMoney(moneyType) or 0
end

---Remove dinheiro com segurança
---@param src number
---@param moneyType string 'cash'|'bank'
---@param amount number
---@param reason string
---@return boolean
function RemovePlayerMoney(src, moneyType, amount, reason)
    local player = GetPlayer(src)
    if not player then return false end
    if player.Functions.GetMoney(moneyType) < amount then return false end
    return player.Functions.RemoveMoney(moneyType, amount, reason or 'vp_newspaper')
end

---Adiciona dinheiro com segurança
---@param src number
---@param moneyType string 'cash'|'bank'
---@param amount number
---@param reason string
---@return boolean
function AddPlayerMoney(src, moneyType, amount, reason)
    local player = GetPlayer(src)
    if not player then return false end
    return player.Functions.AddMoney(moneyType, amount, reason or 'vp_newspaper')
end

---Envio de notificação para o jogador
---@param src number
---@param msg string
---@param notifyType string|nil 'success'|'error'|'info'
function NotifyPlayer(src, msg, notifyType)
    notifyType = notifyType or 'info'
    TriggerClientEvent('vp_newspaper:client:notify', src, msg, notifyType)
end

---Envia log no Discord se configurado
---@param title string
---@param message string
---@param color number|nil
function SendDiscordLog(title, message, color)
    local webhook = Config.General.WebhookURL
    if not webhook or webhook == '' then return end

    local embed = {
        {
            ['title'] = title,
            ['description'] = message,
            ['color'] = color or 3447003,
            ['footer'] = { ['text'] = 'vp_newspaper • ' .. os.date('%d/%m/%Y %H:%M:%S') }
        }
    }
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ username = 'Weazel News Log', embeds = embed }), { ['Content-Type'] = 'application/json' })
end

-- ==========================================================
-- Registro de Item Usável: Jornal
-- ==========================================================

CreateThread(function()
    local newspaperItem = Config.General.newspaperItemName or 'newspaper'
    local boxItem = Config.General.restockBoxesItemName or 'newspaperbox'

    -- 1. QBX Core (Framework principal)
    if GetResourceState('qbx_core') == 'started' and exports.qbx_core and exports.qbx_core.CreateUseableItem then
        exports.qbx_core:CreateUseableItem(newspaperItem, function(source, item)
            TriggerClientEvent('vp_newspaper:client:openReader', source)
        end)
        exports.qbx_core:CreateUseableItem(boxItem, function(source, item)
            TriggerClientEvent('vp_newspaper:client:unpackBoxPrompt', source)
        end)
    end

    -- 2. QBCore fallback
    if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
        QBCore.Functions.CreateUseableItem(newspaperItem, function(source, item)
            TriggerClientEvent('vp_newspaper:client:openReader', source)
        end)
        QBCore.Functions.CreateUseableItem(boxItem, function(source, item)
            TriggerClientEvent('vp_newspaper:client:unpackBoxPrompt', source)
        end)
    end

    -- 3. ox_inventory server hooks
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        exports('useNewspaper', function(event, item, inventory, slot, data)
            if event == 'usingItem' then
                local src = inventory.id
                TriggerClientEvent('vp_newspaper:client:openReader', src)
                return false
            end
        end)
        exports('useNewspaperBox', function(event, item, inventory, slot, data)
            if event == 'usingItem' then
                local src = inventory.id
                TriggerClientEvent('vp_newspaper:client:unpackBoxPrompt', src)
                return false
            end
        end)
    end
end)

-- Notificação genérica vinda de outros módulos
RegisterNetEvent('vp_newspaper:server:notify', function(msg, nType)
    local src = source
    NotifyPlayer(src, msg, nType)
end)

---Define cargo e grau do jogador compatível com QBX e QBCore
---@param targetSrcOrCid number|string
---@param jobName string
---@param grade number
---@return boolean
function SetPlayerJob(targetSrcOrCid, jobName, grade)
    grade = tonumber(grade) or 0
    if GetResourceState('qbx_core') == 'started' then
        if type(targetSrcOrCid) == 'number' then
            return exports.qbx_core:SetJob(targetSrcOrCid, jobName, grade)
        else
            local p = exports.qbx_core:GetPlayerByCitizenId(targetSrcOrCid)
            if p then
                return exports.qbx_core:SetJob(p.PlayerData.source, jobName, grade)
            else
                MySQL.query('UPDATE `players` SET `job` = JSON_SET(`job`, "$.name", ?, "$.grade.level", ?) WHERE `citizenid` = ?', { jobName, grade, targetSrcOrCid })
                return true
            end
        end
    elseif QBCore then
        local p = nil
        if type(targetSrcOrCid) == 'number' then
            p = QBCore.Functions.GetPlayer(targetSrcOrCid)
        else
            p = QBCore.Functions.GetPlayerByCitizenId(targetSrcOrCid)
        end
        if p then
            return p.Functions.SetJob(jobName, grade)
        else
            MySQL.query('UPDATE `players` SET `job` = JSON_SET(`job`, "$.name", ?, "$.grade.level", ?) WHERE `citizenid` = ?', { jobName, grade, targetSrcOrCid })
            return true
        end
    end
    return false
end

-- ==========================================================
-- Spawner Autoritativo de Veículo de Entrega (Weazel Van)
-- ==========================================================

local spawnedDeliveryVehicles = {}

RegisterNetEvent('vp_newspaper:server:spawnDeliveryVehicle', function(requestedModel)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if not Security.CheckRateLimit(src, 'spawn_delivery_vehicle', 'ECONOMIC') then return end

    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas membros da equipe da Weazel News podem retirar veículos!', 'error')
        return
    end

    local okDist = Security.ValidateDistance(src, Config.General.Coords.distributorCoord, 'GARAGE_SPAWN')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar junto à garagem da redação.', 'error')
        return
    end

    if spawnedDeliveryVehicles[src] and DoesEntityExist(spawnedDeliveryVehicles[src]) then
        NotifyPlayer(src, 'Você já possui uma van de entrega em uso!', 'error')
        return
    end

    local chosenModel = Config.General.distributorVehicles[1] or 'rumpo'
    if requestedModel and type(requestedModel) == 'string' then
        for _, validModel in ipairs(Config.General.distributorVehicles or {}) do
            if string.lower(validModel) == string.lower(requestedModel) then
                chosenModel = validModel
                break
            end
        end
    end

    local spawns = Config.General.distributorCoords
    local chosenSpawn = spawns[1]

    local modelHash = joaat(chosenModel)
    local plate = 'WEAZ' .. tostring(math.random(1000, 9999))
    local veh = CreateVehicleServerSetter(modelHash, 'automobile', chosenSpawn.x, chosenSpawn.y, chosenSpawn.z, chosenSpawn.w)

    local waitCount = 0
    while not DoesEntityExist(veh) and waitCount < 25 do
        Wait(50)
        waitCount = waitCount + 1
    end

    if not DoesEntityExist(veh) then
        NotifyPlayer(src, 'Falha ao instanciar veículo de entrega no servidor.', 'error')
        return
    end

    SetVehicleNumberPlateText(veh, plate)
    Entity(veh).state:set('isDeliveryVehicle', true, true)
    spawnedDeliveryVehicles[src] = veh

    -- Concessão de chaves
    if GetResourceState('qbx_vehiclekeys') == 'started' then
        exports.qbx_vehiclekeys:GiveKeys(src, veh)
    elseif GetResourceState('qb-vehiclekeys') == 'started' then
        TriggerClientEvent('qb-vehiclekeys:client:AddKeys', src, plate)
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)
    TriggerClientEvent('vp_newspaper:client:deliveryVehicleSpawned', src, netId, chosenModel)
    NotifyPlayer(src, _U('vehicleSpawned'), 'success')
end)

RegisterNetEvent('vp_newspaper:server:returnDeliveryVehicle', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    local okDist = Security.ValidateDistance(src, Config.General.distributorPutVehicleCoord, 'GARAGE_RETURN')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar na vaga de devolução da redação.', 'error')
        return
    end

    local veh = spawnedDeliveryVehicles[src]
    if veh and DoesEntityExist(veh) then
        DeleteEntity(veh)
        spawnedDeliveryVehicles[src] = nil
        TriggerClientEvent('vp_newspaper:client:deliveryVehicleReturned', src)
        NotifyPlayer(src, _U('vehicleReturned'), 'success')
    else
        NotifyPlayer(src, 'Nenhum veículo de entrega ativo encontrado para devolver.', 'error')
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if spawnedDeliveryVehicles[src] and DoesEntityExist(spawnedDeliveryVehicles[src]) then
        DeleteEntity(spawnedDeliveryVehicles[src])
        spawnedDeliveryVehicles[src] = nil
    end
end)
