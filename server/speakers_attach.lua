-- ==========================================================
-- vp_newspaper: Vehicle Speaker Attachment (Server Authority)
-- Inspired by Rahe Speakers Vehicle Audio Systems
-- ==========================================================

local AttachedVehicleSpeakers = {} -- [vehNetId] = speakerData

---Alterna a fixação de um sistema de som em um veículo
lib.callback.register('vp_newspaper:server:attachSpeakerToVehicle', function(source, vehNetId, attachPoint)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    -- 1. Validação da Entidade Veículo
    if not vehNetId or vehNetId <= 0 then
        return false, 'Identificador de veículo inválido!'
    end

    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return false, 'Veículo não encontrado ou não sincronizado no servidor!'
    end

    -- 2. Verificação de Proximidade (Anti-Exploit / Proximity Check <= 5.0m)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(veh)
    if #(pCoords - vCoords) > 6.0 then
        return false, 'Você está muito longe do veículo!'
    end

    -- 3. Verificação de Velocidade
    if GetEntitySpeed(veh) > 1.2 then
        return false, 'O veículo precisa estar completamente parado para instalar a caixa de som!'
    end

    -- 4. Verificação de Item no Inventário (Se configurado)
    local speakerItem = Config.General.Radio and Config.General.Radio.items and Config.General.Radio.items.portableRadio or 'radio_portable'
    if Config.UseOxInventory then
        local count = exports.ox_inventory:GetItemCount(src, speakerItem)
        if count < 1 then
            return false, 'Você não possui uma caixa de som portátil no inventário!'
        end

        local removed = exports.ox_inventory:RemoveItem(src, speakerItem, 1)
        if not removed then
            return false, 'Falha ao retirar a caixa de som do inventário!'
        end
    end

    -- 5. Registro de Estado e Replicação via StateBag
    local validPoints = { trunk = true, roof = true, bed = true }
    local chosenPoint = validPoints[attachPoint] and attachPoint or 'trunk'

    local speakerData = {
        owner = src,
        citizenid = player.PlayerData.citizenid,
        point = chosenPoint,
        installedAt = os.time(),
        netId = vehNetId
    }

    AttachedVehicleSpeakers[vehNetId] = speakerData
    Entity(veh).state:set('weazelVehicleSpeaker', speakerData, true)

    -- 6. Broadcast para sincronização de props
    TriggerClientEvent('vp_newspaper:client:syncVehicleSpeaker', -1, vehNetId, speakerData)

    -- 7. Log Discord
    SendDiscordLog(
        '🔊 SISTEMA DE SOM INSTALADO EM VEÍCULO',
        ('O cidadão **%s** instalou um sistema de som no veículo (Ponto: %s, NetID: %d).'):format(
            GetPlayerName(src) or 'Jogador',
            chosenPoint:upper(),
            vehNetId
        ),
        3066993
    )

    return true, speakerData
end)

---Desacopla e devolve a caixa de som para o jogador
lib.callback.register('vp_newspaper:server:detachSpeakerFromVehicle', function(source, vehNetId)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    if not vehNetId or vehNetId <= 0 then
        return false, 'Identificador de veículo inválido!'
    end

    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or not DoesEntityExist(veh) then
        return false, 'Veículo não encontrado!'
    end

    -- Proximidade
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then
        return false, 'Você está muito longe do veículo para desinstalar o som!'
    end

    local currentData = Entity(veh).state.weazelVehicleSpeaker
    if not currentData then
        return false, 'Não há nenhuma caixa de som instalada neste veículo!'
    end

    -- Limpa StateBag
    Entity(veh).state:set('weazelVehicleSpeaker', nil, true)
    AttachedVehicleSpeakers[vehNetId] = nil

    -- Devolve item ao inventário
    local speakerItem = Config.General.Radio and Config.General.Radio.items and Config.General.Radio.items.portableRadio or 'radio_portable'
    if Config.UseOxInventory then
        exports.ox_inventory:AddItem(src, speakerItem, 1)
    end

    TriggerClientEvent('vp_newspaper:client:syncVehicleSpeaker', -1, vehNetId, nil)

    SendDiscordLog(
        '🔊 SISTEMA DE SOM DESINSTALADO',
        ('O cidadão **%s** removeu o sistema de som do veículo (NetID: %d).'):format(
            GetPlayerName(src) or 'Jogador',
            vehNetId
        ),
        10070709
    )

    return true
end)

---Limpeza ao parar o recurso
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(AttachedVehicleSpeakers) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and DoesEntityExist(veh) then
            Entity(veh).state:set('weazelVehicleSpeaker', nil, true)
        end
    end
    AttachedVehicleSpeakers = {}
end)
