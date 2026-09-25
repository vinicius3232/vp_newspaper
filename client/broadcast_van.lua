-- ==========================================================
-- vp_newspaper: Broadcast Van & Mobile Transmission Rig (Client)
-- Inspired by Senora Signalworks Mobile Broadcast Unit
-- ==========================================================

local AttachedMastProps = {} -- [vehNetId] = propEntity
local currentNearRigVeh = nil

---Calcula a qualidade do sinal de transmissão (0-100%) baseado em altitude, cobertura física e clima
---Inspirado no algoritmo de propagação de RF do Senora Signalworks
---@param veh number
---@return number signalPercent, string signalTier, string statusMessage
local function CalculateBroadcastSignal(veh)
    local cfg = Config.General.BroadcastVan and Config.General.BroadcastVan.signalCalculation or {}
    local base = cfg.baseSignal or 50
    local coords = GetEntityCoords(veh)

    -- 1. Fator Altitude (Altitudes elevadas como colinas e montanhas amplificam o sinal)
    local maxAlt = cfg.maxAltitude or 160.0
    local altWeight = cfg.altitudeWeight or 40.0
    local altRatio = math.min(1.0, math.max(0.0, (coords.z - 15.0) / (maxAlt - 15.0)))
    local altBonus = altRatio * altWeight

    -- 2. Verificação de Obstrução Vertical (Túnel, garagem coberta, sob viaduto)
    local obstructionPenalty = 0
    local isObstructed = false
    if cfg.overheadObstructionCheck ~= false then
        local rayDist = cfg.obstructionDistance or 25.0
        local rayHandle = StartShapeTestRay(
            coords.x, coords.y, coords.z + 1.5,
            coords.x, coords.y, coords.z + rayDist,
            1 | 16, -- Geometria do mapa e objetos
            veh,
            0
        )
        local _, hit = GetShapeTestResult(rayHandle)
        if hit == 1 then
            isObstructed = true
            obstructionPenalty = cfg.obstructionPenalty or 45
        end
    end

    -- 3. Fator Climático (Chuva torrencial, tempestade e neblina densa causam atenuação eletromagnética)
    local weatherPenalty = 0
    local weatherHash = GetPrevWeatherTypeHashName()
    local badWeatherHashes = {
        [joaat('THUNDER')] = 20,
        [joaat('RAIN')] = 12,
        [joaat('FOGGY')] = 8,
        [joaat('SMOG')] = 5,
        [joaat('BLIZZARD')] = 25,
    }
    if badWeatherHashes[weatherHash] then
        weatherPenalty = badWeatherHashes[weatherHash]
    end

    -- 4. Cálculo Final Normalizado
    local finalSignal = base + altBonus - obstructionPenalty - weatherPenalty
    finalSignal = math.floor(math.max(5, math.min(100, finalSignal)))

    local tier = 'Excelente'
    local statusMsg = 'Sinal de transmissão limpo e sem interferências.'

    if isObstructed then
        tier = 'Obstruído'
        statusMsg = 'Antena bloqueada por cobertura ou estrutura física!'
    elseif finalSignal >= 80 then
        tier = 'Excelente'
        statusMsg = 'Transmissão em alta definição para toda San Andreas.'
    elseif finalSignal >= 50 then
        tier = 'Bom'
        statusMsg = 'Sinal estável com alcance metropolitano.'
    elseif finalSignal >= 25 then
        tier = 'Fraco'
        statusMsg = 'Interferências moderadas detectadas no sinal.'
    else
        tier = 'Crítico'
        statusMsg = 'Sinal instável! Mova a van para terreno mais alto e desobstruído.'
    end

    return finalSignal, tier, statusMsg
end

---Cria e acopla a antena visual ao teto da van
---@param veh number
---@param vehNetId number
local function AttachMastToVehicle(veh, vehNetId)
    if AttachedMastProps[vehNetId] and DoesEntityExist(AttachedMastProps[vehNetId]) then
        return
    end

    local cfg = Config.General.BroadcastVan or {}
    local propModel = joaat(cfg.antennaProp or 'prop_air_mast_01')
    local boneName = cfg.attachBone or 'bodyshell'
    local offset = cfg.attachOffset or vector3(0.0, -1.2, 1.45)
    local rot = cfg.attachRot or vector3(0.0, 0.0, 0.0)

    lib.requestModel(propModel, 5000)

    local coords = GetEntityCoords(veh)
    local prop = CreateObject(propModel, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(prop, false, false)

    local boneIdx = GetEntityBoneIndexByName(veh, boneName)
    if boneIdx == -1 then boneIdx = 0 end

    AttachEntityToEntity(
        prop, veh, boneIdx,
        offset.x, offset.y, offset.z,
        rot.x, rot.y, rot.z,
        false, false, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(propModel)
    AttachedMastProps[vehNetId] = prop
end

---Desacopla e destrói a antena visual da van
---@param vehNetId number
local function DetachMastFromVehicle(vehNetId)
    local prop = AttachedMastProps[vehNetId]
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    AttachedMastProps[vehNetId] = nil
end

---Encontra a van da Weazel News mais próxima do jogador
---@param maxDist number
---@return number|nil veh, number|nil vehNetId
local function GetNearestVan(maxDist)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local allowed = Config.General.BroadcastVan and Config.General.BroadcastVan.allowedModels or { 'rumpo' }

    local allowedHashes = {}
    for _, name in ipairs(allowed) do
        allowedHashes[joaat(name)] = true
    end

    local handle, veh = FindFirstVehicle()
    local success
    local nearestVeh = nil
    local nearestDist = maxDist

    repeat
        if DoesEntityExist(veh) and allowedHashes[GetEntityModel(veh)] then
            local vCoords = GetEntityCoords(veh)
            local dist = #(coords - vCoords)
            if dist < nearestDist then
                nearestDist = dist
                nearestVeh = veh
            end
        end
        success, veh = FindNextVehicle(handle)
    until not success
    EndFindVehicle(handle)

    if nearestVeh then
        local netId = NetworkGetNetworkIdFromEntity(nearestVeh)
        return nearestVeh, netId
    end
    return nil, nil
end

---Inicia a sequência de montagem ou desmontagem da antena
local function ToggleVanRigAction()
    local veh, vehNetId = GetNearestVan(6.0)
    if not veh then
        lib.notify({
            title = 'Unidade Móvel',
            description = 'Nenhuma van de transmissão Weazel News encontrada nas proximidades!',
            type = 'error'
        })
        return
    end

    -- 1. Veículo deve estar parado
    local speed = GetEntitySpeed(veh)
    if speed > 0.8 then
        lib.notify({
            title = 'Unidade Móvel',
            description = 'A van precisa estar completamente parada!',
            type = 'error'
        })
        return
    end

    -- 2. Motor deve estar desligado
    if GetIsVehicleEngineRunning(veh) then
        lib.notify({
            title = 'Unidade Móvel',
            description = 'Desligue o motor da van antes de montar a torre de transmissão!',
            type = 'error'
        })
        return
    end

    -- 3. Verifica estado atual
    local isDeployed = Entity(veh).state.weazelBroadcastRig == true
    local actionLabel = isDeployed and 'Recolhendo torre de transmissão...' or 'Montando torre e alinhando antena móvel...'

    -- 4. Animação de trabalho de campo
    TaskTurnPedToFaceEntity(PlayerPedId(), veh, 1000)
    Wait(600)

    local success = lib.progressBar({
        duration = isDeployed and 3500 or 5000,
        label = actionLabel,
        useWhileDead = false,
        canCancel = true,
        disable = { car = true, move = true, combat = true },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer',
            flag = 1
        }
    })

    if not success then
        lib.notify({ title = 'Unidade Móvel', description = 'Operação cancelada.', type = 'inform' })
        return
    end

    -- 5. Calcula sinal caso esteja implantando
    local signal, tier, statusMsg = CalculateBroadcastSignal(veh)

    -- 6. Chama o servidor com validação autoritativa
    local ok, newState, confirmedSignal = lib.callback.await('vp_newspaper:server:toggleBroadcastRig', false, vehNetId, signal)
    if not ok then
        lib.notify({ title = 'Unidade Móvel', description = newState or 'Falha na operação!', type = 'error' })
        return
    end

    if newState then
        lib.notify({
            title = '📡 Torre Weazel Móvel ATIVADA',
            description = ('Sinal: %d%% (%s)\n%s'):format(confirmedSignal, tier, statusMsg),
            type = 'success',
            duration = 7000
        })
    else
        lib.notify({
            title = '📡 Torre Weazel Móvel RECOLHIDA',
            description = 'Antena desmontada com sucesso. A van está liberada para tráfego.',
            type = 'inform',
            duration = 5000
        })
    end
end

-- ==========================================================
-- Eventos e Sincronização de Estado
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:triggerVanDeploy', function()
    ToggleVanRigAction()
end)

RegisterNetEvent('vp_newspaper:client:syncRigState', function(vehNetId, isDeployed, signal)
    local veh = NetworkDoesNetworkIdExist(vehNetId) and NetworkGetEntityFromNetworkId(vehNetId) or nil
    if not veh or not DoesEntityExist(veh) then return end

    if isDeployed then
        AttachMastToVehicle(veh, vehNetId)
    else
        DetachMastFromVehicle(vehNetId)
    end
end)

-- Monitoramento de StateBag e Streaming contínuo
AddStateBagChangeHandler('weazelBroadcastRig', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local vehNetId = NetworkGetNetworkIdFromEntity(entity)
    if value == true then
        AttachMastToVehicle(entity, vehNetId)
    else
        DetachMastFromVehicle(vehNetId)
    end
end)

-- Loop de proximidade e HUD do operador (Senora Signal Indicator)
CreateThread(function()
    local textUiOpen = false

    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local nearestRigVeh, nearestRigNetId = nil, nil
        local minDist = 8.0

        for netId, prop in pairs(AttachedMastProps) do
            if NetworkDoesNetworkIdExist(netId) then
                local v = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(v) then
                    local d = #(coords - GetEntityCoords(v))
                    if d < minDist then
                        minDist = d
                        nearestRigVeh = v
                        nearestRigNetId = netId
                    end
                end
            end
        end

        if nearestRigVeh then
            currentNearRigVeh = nearestRigVeh
            local sig = Entity(nearestRigVeh).state.weazelBroadcastSignal or 50
            local color = sig >= 80 and '#22c55e' or (sig >= 50 and '#38bdf8' or '#ef4444')

            if not textUiOpen then
                lib.showTextUI(('📡 **Unidade Móvel Weazel** | Sinal: <span style="color:%s; font-weight:bold;">%d%%</span>'):format(color, sig), {
                    position = 'top-right',
                    icon = 'tower-broadcast'
                })
                textUiOpen = true
            end
            Wait(1000)
        else
            currentNearRigVeh = nil
            if textUiOpen then
                lib.hideTextUI()
                textUiOpen = false
            end
            Wait(1500)
        end
    end
end)

-- Suporte a ox_target nas vans da Weazel News
CreateThread(function()
    if not Config.UseOxTarget then return end

    local allowed = Config.General.BroadcastVan and Config.General.BroadcastVan.allowedModels or { 'rumpo' }
    exports.ox_target:addGlobalVehicle({
        {
            name = 'vp_newspaper_van_rig',
            icon = 'fa-solid fa-tower-broadcast',
            label = 'Alternar Torre de Transmissão',
            groups = Config.General.jobName,
            canInteract = function(entity, distance, coords, name)
                if distance > 4.5 then return false end
                local model = GetEntityModel(entity)
                for _, allowedModel in ipairs(allowed) do
                    if joaat(allowedModel) == model then
                        return true
                    end
                end
                return false
            end,
            onSelect = function(data)
                ToggleVanRigAction()
            end
        }
    })
end)

-- Limpeza ao parar o recurso
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(AttachedMastProps) do
        DetachMastFromVehicle(netId)
    end
    AttachedMastProps = {}
    lib.hideTextUI()
end)

---Export para outros módulos checarem se há uma unidade móvel ativa próxima
exports('IsNearBroadcastVan', function()
    return currentNearRigVeh ~= nil, currentNearRigVeh
end)
