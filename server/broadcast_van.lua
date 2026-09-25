-- ==========================================================
-- vp_newspaper: Broadcast Van & Mobile Transmission Rig (Server)
-- Inspired by Senora Signalworks Mobile Broadcast Unit
-- ==========================================================

local activeBroadcastVans = {}

---Verifica se o modelo do veículo é autorizado para transmissão móvel
---@param modelHash number
---@return boolean
local function IsAuthorizedVanModel(modelHash)
    local allowed = Config.General.BroadcastVan and Config.General.BroadcastVan.allowedModels or { 'rumpo' }
    for _, modelName in ipairs(allowed) do
        if joaat(modelName) == modelHash then
            return true
        end
    end
    return false
end

---Alterna o estado da torre de transmissão (Rig) na van
lib.callback.register('vp_newspaper:server:toggleBroadcastRig', function(source, vehNetId, clientSignal)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    -- 1. Autorização: Repórteres qualificados ou Admins
    local minGrade = Config.General.BroadcastVan and Config.General.BroadcastVan.minGrade or 1
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, minGrade, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')

    if not isReporter and not isAdmin then
        return false, 'Você não possui permissão para operar a unidade móvel de transmissão!'
    end

    -- 2. Validação da Entidade Veículo
    if not vehNetId or vehNetId <= 0 then
        return false, 'Identificador de veículo inválido!'
    end

    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return false, 'Veículo não encontrado ou não sincronizado no servidor!'
    end

    -- 3. Verificação de Modelo
    local model = GetEntityModel(veh)
    if not IsAuthorizedVanModel(model) then
        return false, 'Este veículo não possui suporte para antena de transmissão móvel!'
    end

    -- 4. Verificação de Proximidade (Anti-Exploit / Proximity Check)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(veh)
    local maxDist = Config.General.BroadcastVan and Config.General.BroadcastVan.maxInteractionDistance or 6.0

    if #(pCoords - vCoords) > maxDist then
        return false, 'Você está muito longe da van de transmissão!'
    end

    -- 5. Verificação de Movimento (Veículo deve estar parado)
    local speed = GetEntitySpeed(veh)
    local maxSpeed = Config.General.BroadcastVan and Config.General.BroadcastVan.maxDeploySpeed or 0.8
    if speed > maxSpeed then
        return false, 'A van deve estar completamente parada para montar ou recolher a antena!'
    end

    -- 6. Alternância de Estado com StateBag Replicado
    local currentState = Entity(veh).state.weazelBroadcastRig == true
    local newState = not currentState
    local sanitizedSignal = math.floor(math.max(5, math.min(100, tonumber(clientSignal) or 50)))

    Entity(veh).state:set('weazelBroadcastRig', newState, true)
    Entity(veh).state:set('weazelBroadcastSignal', newState and sanitizedSignal or 0, true)
    Entity(veh).state:set('weazelRigOperator', newState and src or 0, true)

    if newState then
        activeBroadcastVans[vehNetId] = {
            netId = vehNetId,
            operator = src,
            signal = sanitizedSignal,
            deployedAt = os.time(),
        }
    else
        activeBroadcastVans[vehNetId] = nil
    end

    -- 7. Sincronização Broadcast para clientes locais
    TriggerClientEvent('vp_newspaper:client:syncRigState', -1, vehNetId, newState, sanitizedSignal)

    -- 8. Log Discord
    SendDiscordLog(
        newState and '📡 UNIDADE MÓVEL DE TRANSMISSÃO IMPLANTADA' or '📡 UNIDADE MÓVEL RECOLHIDA',
        ('O repórter **%s** %s a antena de transmissão na van Weazel News.\n**Sinal:** %d%%\n**NetID:** %d'):format(
            GetPlayerName(src) or 'Repórter',
            newState and 'implantou' or 'recolheu',
            sanitizedSignal,
            vehNetId
        ),
        newState and 3066993 or 10070709
    )

    return true, newState, sanitizedSignal
end)

---Retorna o estado atual da torre de um veículo
lib.callback.register('vp_newspaper:server:getRigStatus', function(source, vehNetId)
    if not vehNetId or vehNetId <= 0 then return false end
    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or not DoesEntityExist(veh) then return false end

    local isDeployed = Entity(veh).state.weazelBroadcastRig == true
    local signal = Entity(veh).state.weazelBroadcastSignal or 0
    return isDeployed, signal
end)

---Comando alternativo para implantar a antena da van
RegisterCommand('implantarvan', function(source, args)
    local src = source
    if src == 0 then
        print('^3[vp_newspaper]^7 Este comando deve ser executado no jogo.')
        return
    end

    local minGrade = Config.General.BroadcastVan and Config.General.BroadcastVan.minGrade or 1
    if not Security.IsAuthorized(src, Config.General.jobName, minGrade, false) and not IsPlayerAceAllowed(tostring(src), 'command') then
        NotifyPlayer(src, 'Você não possui autorização para operar a unidade móvel!', 'error')
        return
    end

    TriggerClientEvent('vp_newspaper:client:triggerVanDeploy', src)
end, false)

---Cleanup em caso de parada do resource
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(activeBroadcastVans) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and DoesEntityExist(veh) then
            Entity(veh).state:set('weazelBroadcastRig', false, true)
            Entity(veh).state:set('weazelBroadcastSignal', 0, true)
        end
    end
    activeBroadcastVans = {}
end)
