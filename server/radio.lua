-- ==========================================================
-- vp_newspaper: Weazel Radio 98.5 FM (Server Broadcasting Engine)
-- ==========================================================

local StationState = {
    name = Config.General.Radio and Config.General.Radio.stationName or 'Weazel News Radio 98.5 FM',
    frequency = Config.General.Radio and Config.General.Radio.frequency or '98.5',
    isPlaying = false,
    currentTrack = nil,
    trackStartedAt = 0,
    queue = {},
}

-- Inicializa fila com faixas padrão
CreateThread(function()
    local defaultTracks = Config.General.Radio and Config.General.Radio.defaultTracks or {}
    for _, t in ipairs(defaultTracks) do
        table.insert(StationState.queue, {
            title = t.title or 'Faixa Weazel News',
            url = t.url,
            duration = t.duration or 180,
            addedBy = 'Weazel News'
        })
    end

    if #StationState.queue > 0 then
        StationState.currentTrack = table.remove(StationState.queue, 1)
        StationState.isPlaying = true
        StationState.trackStartedAt = os.time()
    end
end)

---Retorna o estado serializado da estação com o tempo decorrido calculado
local function GetBroadcastingState()
    local elapsed = 0
    if StationState.isPlaying and StationState.trackStartedAt > 0 then
        elapsed = math.max(0, os.time() - StationState.trackStartedAt)
    end

    return {
        name = StationState.name,
        frequency = StationState.frequency,
        isPlaying = StationState.isPlaying,
        currentTrack = StationState.currentTrack,
        elapsed = elapsed,
        queueCount = #StationState.queue,
        queue = StationState.queue
    }
end

local SpeakerAudioStates = {} -- [speakerId] = { speakerId, isPlaying, url, title, startTime, volume, range, isRadio }

RegisterNetEvent('vp_newspaper:server:requestRadioState', function()
    local src = source
    local syncedSpeakers = {}
    local now = os.time()
    for id, spk in pairs(SpeakerAudioStates) do
        local copy = {}
        for k, v in pairs(spk) do copy[k] = v end
        if copy.isPlaying and copy.startTime and copy.startTime > 0 then
            copy.elapsed = math.max(0, now - copy.startTime)
        else
            copy.elapsed = 0
        end
        syncedSpeakers[id] = copy
    end
    TriggerClientEvent('vp_newspaper:client:syncRadioState', src, GetBroadcastingState())
    TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', src, ActiveGroundSpeakers)
    TriggerClientEvent('vp_newspaper:client:syncAllSpeakersAudio', src, syncedSpeakers)
end)

-- ==========================================================
-- Controle da Mesa de Som / DJ (Weazel News Team)
-- ==========================================================

---Avança para a próxima faixa da fila
local function PlayNextTrack()
    if #StationState.queue > 0 then
        StationState.currentTrack = table.remove(StationState.queue, 1)
        StationState.isPlaying = true
        StationState.trackStartedAt = os.time()
    else
        -- Repõe faixas padrão se a fila esvaziar
        local defaultTracks = Config.General.Radio and Config.General.Radio.defaultTracks or {}
        if #defaultTracks > 0 then
            local fallback = defaultTracks[1]
            StationState.currentTrack = {
                title = fallback.title,
                url = fallback.url,
                duration = fallback.duration or 180,
                addedBy = 'Weazel News'
            }
            StationState.isPlaying = true
            StationState.trackStartedAt = os.time()
        else
            StationState.currentTrack = nil
            StationState.isPlaying = false
            StationState.trackStartedAt = 0
        end
    end

    TriggerClientEvent('vp_newspaper:client:syncRadioState', -1, GetBroadcastingState())
end

RegisterNetEvent('vp_newspaper:server:addRadioTrack', function(url, title)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- 1. Autorização
    local minGrade = Config.General.Radio and Config.General.Radio.djMinGrade or 1
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, minGrade, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
       or IsPlayerAceAllowed(tostring(src), 'group.admin')
       or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isReporter and not isAdmin then
        NotifyPlayer(src, 'Apenas membros da equipe da Weazel News podem operar a mesa de som!', 'error')
        return
    end

    -- 2. Sanitização da URL
    if type(url) ~= 'string' or #url < 10 or #url > 500 then
        NotifyPlayer(src, 'Link de áudio ou vídeo do YouTube inválido!', 'error')
        return
    end

    local cleanTitle = (type(title) == 'string' and #title > 0) and title:gsub('<[^>]*>', ''):sub(1, 60) or 'Faixa Musical'

    table.insert(StationState.queue, {
        title = cleanTitle,
        url = url,
        duration = 240,
        addedBy = GetPlayerName(src) or 'Repórter'
    })

    if not StationState.isPlaying or not StationState.currentTrack then
        PlayNextTrack()
    else
        TriggerClientEvent('vp_newspaper:client:syncRadioState', -1, GetBroadcastingState())
    end

    NotifyPlayer(src, ('Faixa "%s" adicionada à programação da Weazel Radio!'):format(cleanTitle), 'success')
    SendDiscordLog('Música Adicionada à Weazel Radio', ('O locutor **%s** adicionou a faixa **"%s"** na rádio.\nLink: %s'):format(GetPlayerName(src), cleanTitle, url), 3066993)
end)

RegisterNetEvent('vp_newspaper:server:skipRadioTrack', function()
    local src = source
    local minGrade = Config.General.Radio and Config.General.Radio.djMinGrade or 1
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, minGrade, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
       or IsPlayerAceAllowed(tostring(src), 'group.admin')
       or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isReporter and not isAdmin then return end

    PlayNextTrack()
    NotifyPlayer(src, 'Faixa pulada na programação da rádio.', 'info')
end)

RegisterNetEvent('vp_newspaper:server:toggleRadioPause', function()
    local src = source
    local minGrade = Config.General.Radio and Config.General.Radio.djMinGrade or 1
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, minGrade, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
       or IsPlayerAceAllowed(tostring(src), 'group.admin')
       or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isReporter and not isAdmin then return end

    StationState.isPlaying = not StationState.isPlaying
    TriggerClientEvent('vp_newspaper:client:syncRadioState', -1, GetBroadcastingState())
end)

local lastAutoTrackAdvance = 0

RegisterNetEvent('vp_newspaper:server:reportTrackEnded', function()
    local src = source
    local now = os.time()

    -- Proteção contra spam de skip (Anti-Griefing)
    if now - lastAutoTrackAdvance < 10 then return end

    -- Validação: a faixa atual precisa ter tocado por pelo menos 15 segundos ou atingido sua duração
    if StationState.currentTrack and StationState.trackStartedAt > 0 then
        local playedDuration = now - StationState.trackStartedAt
        local trackDuration = StationState.currentTrack.duration or 180
        if playedDuration < 15 and playedDuration < trackDuration then
            return
        end
    end

    lastAutoTrackAdvance = now
    PlayNextTrack()
end)

-- ==========================================================
-- Interceptação de Plantão Urgente (Breaking News)
-- ==========================================================

AddEventHandler('vp_newspaper:server:broadcastBreakingNews', function()
    -- Notifica todos os receptores para atenuarem o áudio durante o plantão
    TriggerClientEvent('vp_newspaper:client:radioAttenuate', -1, 0.15)

    local duration = Config.General.Media and Config.General.Media.breakingNews.durationMs or 9000
    SetTimeout(duration + 1000, function()
        TriggerClientEvent('vp_newspaper:client:radioRestoreVolume', -1)
    end)
end)

-- ==========================================================
-- Itens Usáveis (Fones de Ouvido & Rádio Portátil)
-- ==========================================================

CreateThread(function()
    local items = Config.General.Radio and Config.General.Radio.items
    if not items then return end

    -- Todos os itens de caixa de som (radio_portable legado + os 4 tipos novos)
    local speakerItems = { items.portableRadio or 'radio_portable' }
    if Config.General.SpeakerTypes then
        for typeId, typeData in pairs(Config.General.SpeakerTypes) do
            if typeData.item then
                speakerItems[#speakerItems + 1] = typeData.item
            end
        end
    end

    if GetResourceState('ox_inventory') == 'started' then
        if items.headphones then
            exports.ox_inventory:registerHook('useItem', function(payload)
                if payload.item.name == items.headphones then
                    TriggerClientEvent('vp_newspaper:client:toggleHeadphones', payload.source)
                    return false
                end
            end)
        end

        -- Registra radio_portable e todos os speaker_* via ox_inventory
        for _, itemName in ipairs(speakerItems) do
            local capturedItem = itemName
            exports.ox_inventory:registerHook('useItem', function(payload)
                if payload.item.name == capturedItem then
                    -- Detecta o tipo do item e passa como metadado
                    local speakerType = 'retro' -- padrão (radio_portable legado)
                    if Config.General.SpeakerTypes then
                        for typeId, typeData in pairs(Config.General.SpeakerTypes) do
                            if typeData.item == capturedItem then
                                speakerType = typeId
                                break
                            end
                        end
                    end
                    TriggerClientEvent('vp_newspaper:client:openPortableRadioMenu', payload.source, speakerType)
                    return false
                end
            end)
        end
    end

    if GetResourceState('qbx_core') == 'started' and exports.qbx_core and exports.qbx_core.CreateUseableItem then
        if items.headphones then
            exports.qbx_core:CreateUseableItem(items.headphones, function(source, item)
                TriggerClientEvent('vp_newspaper:client:toggleHeadphones', source)
            end)
        end
        for _, itemName in ipairs(speakerItems) do
            local capturedItem = itemName
            exports.qbx_core:CreateUseableItem(capturedItem, function(source, item)
                local speakerType = 'retro'
                if Config.General.SpeakerTypes then
                    for typeId, typeData in pairs(Config.General.SpeakerTypes) do
                        if typeData.item == capturedItem then speakerType = typeId; break end
                    end
                end
                TriggerClientEvent('vp_newspaper:client:openPortableRadioMenu', source, speakerType)
            end)
        end
    end

    if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
        if items.headphones then
            QBCore.Functions.CreateUseableItem(items.headphones, function(source, item)
                TriggerClientEvent('vp_newspaper:client:toggleHeadphones', source)
            end)
        end
        for _, itemName in ipairs(speakerItems) do
            local capturedItem = itemName
            QBCore.Functions.CreateUseableItem(capturedItem, function(source, item)
                local speakerType = 'retro'
                if Config.General.SpeakerTypes then
                    for typeId, typeData in pairs(Config.General.SpeakerTypes) do
                        if typeData.item == capturedItem then speakerType = typeId; break end
                    end
                end
                TriggerClientEvent('vp_newspaper:client:openPortableRadioMenu', source, speakerType)
            end)
        end
    end
end)

-- Comandos Públicos e de Equipe
RegisterCommand('weazelradio', function(source)
    TriggerClientEvent('vp_newspaper:client:openRadioMenu', source)
end, false)

RegisterCommand('weazeldj', function(source)
    TriggerClientEvent('vp_newspaper:client:openDjMenu', source)
end, false)

-- ==========================================================
-- Sistema de Som Veicular Integrado (Rahe Speakers Engineering)
-- ==========================================================

local AttachedVehicleSpeakers = {} -- [vehNetId] = speakerData

---Insta---Acopla o sistema de som portátil no veículo
lib.callback.register('vp_newspaper:server:attachSpeakerToVehicle', function(source, vehNetId, attachPoint, speakerType)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    if not vehNetId or vehNetId <= 0 then
        return false, 'Identificador de veículo inválido!'
    end

    local veh = NetworkGetEntityFromNetworkId(vehNetId)
    if not veh or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then
        return false, 'Veículo não encontrado ou não sincronizado no servidor!'
    end

    -- Proximidade Física Server-Side (Máximo 6.0 metros)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(veh)
    if #(pCoords - vCoords) > 6.0 then
        return false, 'Você está muito longe do veículo!'
    end

    -- Veículo estático
    if GetEntitySpeed(veh) > 1.2 then
        return false, 'O veículo precisa estar completamente parado para instalar a caixa de som!'
    end

    -- Resolve o item de acordo com o speakerType
    speakerType = speakerType or 'retro'
    local speakerItem = (Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType] and Config.General.SpeakerTypes[speakerType].item)
        or (Config.General.Radio and Config.General.Radio.items and Config.General.Radio.items.portableRadio)
        or 'radio_portable'

    -- Consome o item no inventário (Fail-Closed)
    if Config.UseOxInventory then
        local count = exports.ox_inventory:GetItemCount(src, speakerItem)
        if count < 1 then
            return false, 'Você não possui esta caixa de som no inventário!'
        end

        local removed = exports.ox_inventory:RemoveItem(src, speakerItem, 1)
        if not removed then
            return false, 'Falha ao retirar a caixa de som do inventário!'
        end
    elseif QBCore then
        local hasItem = player.Functions.GetItemByName(speakerItem)
        if not hasItem or hasItem.amount < 1 then
            return false, 'Você não possui esta caixa de som no inventário!'
        end
        player.Functions.RemoveItem(speakerItem, 1)
    end

    local validPoints = { trunk = true, roof = true, bed = true }
    local chosenPoint = validPoints[attachPoint] and attachPoint or 'trunk'

    local speakerData = {
        owner = src,
        citizenid = player.PlayerData.citizenid,
        point = chosenPoint,
        installedAt = os.time(),
        netId = vehNetId,
        speakerType = speakerType
    }

    AttachedVehicleSpeakers[vehNetId] = speakerData
    Entity(veh).state:set('weazelVehicleSpeaker', speakerData, true)

    local vehSpeakerKey = 'veh_' .. tostring(vehNetId)
    if not SpeakerAudioStates[vehSpeakerKey] then
        SpeakerAudioStates[vehSpeakerKey] = {
            speakerId = vehSpeakerKey,
            isPlaying = false,
            speakerTypeId = speakerType
        }
    else
        SpeakerAudioStates[vehSpeakerKey].speakerTypeId = speakerType
    end

    TriggerClientEvent('vp_newspaper:client:syncVehicleSpeaker', -1, vehNetId, speakerData)

    SendDiscordLog(
        '🔊 SISTEMA DE SOM INSTALADO EM VEÍCULO',
        ('O cidadão **%s** instalou um sistema de som no veículo (Ponto: %s, Modelo: %s, NetID: %d).'):format(
            GetPlayerName(src) or 'Jogador',
            chosenPoint:upper(),
            speakerType,
            vehNetId
        ),
        3066993
    )

    return true, speakerData
end)

---Desinstala o sistema de som do veículo e devolve o item correto
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

    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - GetEntityCoords(veh)) > 6.0 then
        return false, 'Você está muito longe do veículo para desinstalar o som!'
    end

    local currentData = Entity(veh).state.weazelVehicleSpeaker
    if not currentData then
        return false, 'Não há nenhuma caixa de som instalada neste veículo!'
    end

    local speakerType = currentData.speakerType or 'retro'

    Entity(veh).state:set('weazelVehicleSpeaker', nil, true)
    AttachedVehicleSpeakers[vehNetId] = nil

    local vehSpeakerKey = 'veh_' .. tostring(vehNetId)
    if SpeakerAudioStates[vehSpeakerKey] then
        SpeakerAudioStates[vehSpeakerKey] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, vehSpeakerKey, nil)
    end

    local speakerItem = (Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType] and Config.General.SpeakerTypes[speakerType].item)
        or (Config.General.Radio and Config.General.Radio.items and Config.General.Radio.items.portableRadio)
        or 'radio_portable'

    if Config.UseOxInventory then
        exports.ox_inventory:AddItem(src, speakerItem, 1)
    elseif QBCore then
        player.Functions.AddItem(speakerItem, 1)
    end

    TriggerClientEvent('vp_newspaper:client:syncVehicleSpeaker', -1, vehNetId, nil)

    SendDiscordLog(
        '🔊 SISTEMA DE SOM DESINSTALADO',
        ('O cidadão **%s** removeu o sistema de som do veículo (Modelo: %s, NetID: %d).'):format(
            GetPlayerName(src) or 'Jogador',
            speakerType,
            vehNetId
        ),
        10070709
    )

    return true
end)

-- ==========================================================
-- Sincronização de Caixas de Som de Chão (Ground Speakers Sync)
-- ==========================================================

local ActiveGroundSpeakers = {} -- [netId] = { coords = vector3, owner = src, speakerType = string }

RegisterNetEvent('vp_newspaper:server:registerGroundSpeaker', function(coords, netId, transferFromCarried, speakerType)
    local src = source
    if not coords or not netId or netId <= 0 then return end

    speakerType = speakerType or 'retro'

    ActiveGroundSpeakers[netId] = {
        coords = vector3(coords.x, coords.y, coords.z),
        owner = src,
        speakerType = speakerType,
        placedAt = os.time()
    }

    local groundKey = 'ground_' .. tostring(netId)

    if transferFromCarried then
        local carriedKey = 'carried_' .. tostring(src)
        local carriedState = SpeakerAudioStates[carriedKey]
        if carriedState then
            carriedState.speakerId = groundKey
            carriedState.speakerTypeId = speakerType
            SpeakerAudioStates[groundKey] = carriedState
            SpeakerAudioStates[carriedKey] = nil
            TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, carriedKey, nil)
            TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, groundKey, carriedState)
        end
    else
        if SpeakerAudioStates[groundKey] then
            SpeakerAudioStates[groundKey].speakerTypeId = speakerType
        end
    end

    TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)
end)

lib.callback.register('vp_newspaper:server:carryGroundSpeaker', function(source, netId)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    local speakerData = ActiveGroundSpeakers[netId]
    if not speakerData then
        return false, 'Caixa de som não encontrada ou já recolhida!'
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - speakerData.coords) > 4.0 then
        return false, 'Você está muito longe para pegar a caixa de som!'
    end

    local speakerType = speakerData.speakerType or 'retro'
    ActiveGroundSpeakers[netId] = nil

    local groundSpeakerKey = 'ground_' .. tostring(netId)
    local carriedSpeakerKey = 'carried_' .. tostring(src)
    local existingAudio = SpeakerAudioStates[groundSpeakerKey]

    if existingAudio then
        existingAudio.speakerId = carriedSpeakerKey
        existingAudio.speakerTypeId = speakerType
        SpeakerAudioStates[carriedSpeakerKey] = existingAudio
        SpeakerAudioStates[groundSpeakerKey] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, groundSpeakerKey, nil)
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, carriedSpeakerKey, existingAudio)
    end

    TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)
    return true, existingAudio, speakerType
end)

lib.callback.register('vp_newspaper:server:pickupGroundSpeaker', function(source, netId)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    local speakerData = ActiveGroundSpeakers[netId]
    if not speakerData then
        return false, 'Caixa de som não encontrada ou já recolhida!'
    end

    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - speakerData.coords) > 4.0 then
        return false, 'Você está muito longe para pegar a caixa de som!'
    end

    local speakerType = speakerData.speakerType or 'retro'
    ActiveGroundSpeakers[netId] = nil

    local groundSpeakerKey = 'ground_' .. tostring(netId)
    if SpeakerAudioStates[groundSpeakerKey] then
        SpeakerAudioStates[groundSpeakerKey] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, groundSpeakerKey, nil)
    end

    -- Devolve o item correto ao inventário (Anti-Downgrade)
    local speakerItem = (Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType] and Config.General.SpeakerTypes[speakerType].item)
        or (Config.General.Radio and Config.General.Radio.items and Config.General.Radio.items.portableRadio)
        or 'radio_portable'

    if Config.UseOxInventory then
        exports.ox_inventory:AddItem(src, speakerItem, 1)
    elseif QBCore then
        player.Functions.AddItem(speakerItem, 1)
    end

    TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)
    return true
end)

-- ==========================================================
-- Gerenciamento de Áudio de Caixas de Som Individuais (Rahe Pattern)
-- ==========================================================

local function SaveSongToHistory(src, url, title)
    local player = GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end
    local cid = player.PlayerData.citizenid

    local cleanTitle = (type(title) == 'string' and #title > 0) and title:sub(1, 100) or 'Música (YouTube/Web)'

    MySQL.insert([[
        INSERT INTO `newspaper_speaker_history` (`citizenid`, `url`, `title`)
        VALUES (?, ?, ?)
    ]], { cid, url, cleanTitle })
end

RegisterNetEvent('vp_newspaper:server:playSpeakerMusic', function(speakerId, url, timestamp)
    local src = source
    if type(url) == 'string' then
        url = url:gsub('^%s*(.-)%s*$', '%1')
    end
    if not speakerId or type(url) ~= 'string' or #url < 6 or #url > 500 then
        NotifyPlayer(src, 'Link de áudio ou vídeo inválido!', 'error')
        return
    end

    local skipSeconds = math.max(0, tonumber(timestamp) or 0)

    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = {
            speakerId = speakerId,
            volume = 0.8,
            range = 25.0,
        }
    end

    SpeakerAudioStates[speakerId].isPlaying = true
    SpeakerAudioStates[speakerId].url = url
    SpeakerAudioStates[speakerId].startTime = os.time() - skipSeconds
    SpeakerAudioStates[speakerId].elapsed = skipSeconds
    SpeakerAudioStates[speakerId].isRadio = false
    SpeakerAudioStates[speakerId].title = 'Música (YouTube/Web)'

    SaveSongToHistory(src, url, 'Música (YouTube/Web)')

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    NotifyPlayer(src, '▶ Reproduzindo música na caixa de som!', 'success')
end)

RegisterNetEvent('vp_newspaper:server:pauseSpeakerMusic', function(speakerId)
    local src = source
    if not speakerId or not SpeakerAudioStates[speakerId] then return end

    SpeakerAudioStates[speakerId].isPlaying = not SpeakerAudioStates[speakerId].isPlaying
    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])

    local stateMsg = SpeakerAudioStates[speakerId].isPlaying and '▶ Reprodução retomada.' or '⏸ Reprodução pausada.'
    NotifyPlayer(src, stateMsg, 'info')
end)

RegisterNetEvent('vp_newspaper:server:stopSpeakerMusic', function(speakerId)
    local src = source
    if not speakerId or not SpeakerAudioStates[speakerId] then return end

    SpeakerAudioStates[speakerId].isPlaying = false
    SpeakerAudioStates[speakerId].url = nil
    SpeakerAudioStates[speakerId].isRadio = false
    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    NotifyPlayer(src, '⏹ Reprodução parada.', 'info')
end)

RegisterNetEvent('vp_newspaper:server:setSpeakerVolumeRange', function(speakerId, volume, range)
    local src = source
    if not speakerId then return end

    -- Resolve os limites máximos pelo tipo da caixa (BUG FIX: era hardcoded 45m/1.0)
    local speakerState = SpeakerAudioStates[speakerId]
    local speakerTypeId = speakerState and speakerState.speakerTypeId  -- pode ser nil em caixas legadas
    local typeCfg = Config.General.SpeakerTypes and speakerTypeId and Config.General.SpeakerTypes[speakerTypeId]
    local maxRange  = (typeCfg and typeCfg.maxRange)  or 45.0  -- legado: 45m
    local maxVolume = (typeCfg and typeCfg.maxVolume) or 1.0   -- legado: 100%

    local clampedVol   = math.max(0.1, math.min(maxVolume, tonumber(volume) or 0.8))
    local clampedRange = math.max(1.0, math.min(maxRange,  tonumber(range)  or 25.0))

    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = {
            speakerId = speakerId,
            isPlaying = false,
        }
    end

    SpeakerAudioStates[speakerId].volume = clampedVol
    SpeakerAudioStates[speakerId].range = clampedRange

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    NotifyPlayer(src, ('Volume: %d%% | Alcance: %.0fm (máx: %.0fm)'):format(
        math.floor(clampedVol * 100), clampedRange, maxRange), 'success')
end)

RegisterNetEvent('vp_newspaper:server:tuneSpeakerToRadio', function(speakerId)
    local src = source
    if not speakerId then return end

    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = {
            speakerId = speakerId,
            volume = 0.8,
            range = 25.0,
        }
    end

    SpeakerAudioStates[speakerId].isPlaying = true
    SpeakerAudioStates[speakerId].isRadio = true
    SpeakerAudioStates[speakerId].url = nil
    SpeakerAudioStates[speakerId].title = 'Weazel Radio 98.5 FM'

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    NotifyPlayer(src, '📻 Caixa sintonizada na Weazel Radio 98.5 FM!', 'success')
end)

RegisterNetEvent('vp_newspaper:server:clearSpeakerAudio', function(speakerId)
    if speakerId and SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, nil)
    end
end)

-- ==========================================================
-- Sistema de Grupos de Caixas de Som (Multi-Speaker Sync)
-- Permite sincronizar múltiplas caixas para tocar a mesma
-- música em perfeita sincronia (estilo sistema PA de festa)
-- ==========================================================

local SpeakerGroups = {} -- [groupId] = { name, connectCode, accessCode, leaderSrc, speakerIds = {}, isPlaying, url, startTime, volume, title }
local _groupCounter  = 0

local function GenerateCode(len)
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local s = ''
    for _ = 1, len do
        local idx = math.random(1, #chars)
        s = s .. chars:sub(idx, idx)
    end
    return s
end

---Retorna o groupId ao qual um speakerId pertence (ou nil)
local function FindGroupBySpeaker(speakerId)
    for gid, group in pairs(SpeakerGroups) do
        for _, sid in ipairs(group.speakerIds) do
            if sid == speakerId then return gid, group end
        end
    end
    return nil, nil
end

---Propaga o estado de áudio do grupo para todos os membros satélite
local function SyncGroupToMembers(group)
    for _, sid in ipairs(group.speakerIds) do
        if not SpeakerAudioStates[sid] then
            SpeakerAudioStates[sid] = { speakerId = sid, volume = group.volume or 0.8, range = 25.0 }
        end
        SpeakerAudioStates[sid].isPlaying  = group.isPlaying
        SpeakerAudioStates[sid].url        = group.url
        SpeakerAudioStates[sid].startTime  = group.startTime
        SpeakerAudioStates[sid].elapsed    = group.elapsed or 0
        SpeakerAudioStates[sid].isRadio    = group.isRadio or false
        SpeakerAudioStates[sid].title      = group.title or 'Grupo de Som'
        SpeakerAudioStates[sid].groupId    = group.id
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, sid, SpeakerAudioStates[sid])
    end
end

-- Cria um novo grupo e faz a caixa do líder ser o mestre
RegisterNetEvent('vp_newspaper:server:createSpeakerGroup', function(speakerId, groupName)
    local src = source
    if not speakerId or type(speakerId) ~= 'string' then return end

    -- SECURITY: valida que o speakerId pertence ao caller
    -- carried_{src} é do player, ground_{netId} pode ser verificado pelo owner no estado
    local expectedCarried = 'carried_' .. tostring(src)
    local isOwnerCarried  = (speakerId == expectedCarried)
    local isOwnerGround   = false
    if not isOwnerCarried and SpeakerAudioStates[speakerId] then
        -- ground speakers: verificamos se o estado existe mas não temos owner explícito
        -- como mitigação: aceitamos se o speaker foi registrado pelo mesmo src
        local groundState = SpeakerAudioStates[speakerId]
        isOwnerGround = (groundState.ownerSrc == nil) or (groundState.ownerSrc == src)
    end

    if not isOwnerCarried and not isOwnerGround then
        print(('[vp_newspaper] SECURITY: source %d tentou criar grupo com speakerId "%s" que não lhe pertence'):format(src, speakerId))
        return
    end

    -- Remove de qualquer grupo anterior
    local oldGid, _ = FindGroupBySpeaker(speakerId)
    if oldGid then
        local g = SpeakerGroups[oldGid]
        for i, sid in ipairs(g.speakerIds) do
            if sid == speakerId then table.remove(g.speakerIds, i); break end
        end
        if #g.speakerIds == 0 then SpeakerGroups[oldGid] = nil end
    end

    _groupCounter = _groupCounter + 1
    local groupId = 'grp_' .. tostring(_groupCounter)
    local connectCode = GenerateCode(5)
    local accessCode  = GenerateCode(6)
    local name = (type(groupName) == 'string' and #groupName > 0) and groupName:sub(1, 30) or 'Grupo de Som'

    SpeakerGroups[groupId] = {
        id          = groupId,
        name        = name,
        connectCode = connectCode,
        accessCode  = accessCode,
        leaderSrc   = src,
        speakerIds  = { speakerId },
        isPlaying   = false,
        url         = nil,
        startTime   = 0,
        volume      = 0.8,
        title       = 'Aguardando...',
    }

    -- Marca o speakerAudio do líder com o groupId e o ownerSrc
    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false }
    end
    SpeakerAudioStates[speakerId].groupId  = groupId
    SpeakerAudioStates[speakerId].ownerSrc = src

    TriggerClientEvent('vp_newspaper:client:speakerGroupCreated', src, {
        groupId     = groupId,
        name        = name,
        connectCode = connectCode,
        accessCode  = accessCode,
    })
    NotifyPlayer(src, ('🎶 Grupo "%s" criado!\nCódigo para convidar: %s'):format(name, connectCode), 'success')
end)

-- Conecta uma caixa a um grupo existente via código
RegisterNetEvent('vp_newspaper:server:joinSpeakerGroup', function(speakerId, connectCode)
    local src = source
    if not speakerId or not connectCode then return end

    -- SECURITY: case-insensitive + normaliza entrada do usuário (BUG FIX: era case-sensitive)
    local normalizedCode = string.upper(tostring(connectCode):gsub('%s', ''))

    local targetGid, targetGroup = nil, nil
    for gid, group in pairs(SpeakerGroups) do
        if string.upper(group.connectCode) == normalizedCode then
            targetGid   = gid
            targetGroup = group
            break
        end
    end

    if not targetGroup then
        NotifyPlayer(src, 'Código de grupo inválido ou grupo não encontrado!', 'error')
        return
    end

    -- Sai do grupo anterior (se houver)
    local oldGid, _ = FindGroupBySpeaker(speakerId)
    if oldGid and oldGid ~= targetGid then
        local g = SpeakerGroups[oldGid]
        for i, sid in ipairs(g.speakerIds) do
            if sid == speakerId then table.remove(g.speakerIds, i); break end
        end
        if #g.speakerIds == 0 then SpeakerGroups[oldGid] = nil end
    end

    -- Já está no grupo
    if oldGid == targetGid then
        NotifyPlayer(src, 'Sua caixa já está neste grupo!', 'inform')
        return
    end

    table.insert(targetGroup.speakerIds, speakerId)

    -- Rastreia ownerSrc da caixa que entrou
    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false }
    end
    SpeakerAudioStates[speakerId].ownerSrc = src

    SyncGroupToMembers(targetGroup)

    TriggerClientEvent('vp_newspaper:client:speakerGroupJoined', src, {
        groupId     = targetGid,
        name        = targetGroup.name,
        connectCode = targetGroup.connectCode,
    })
    NotifyPlayer(src, ('🔗 Conectado ao grupo "%s"! Áudio sincronizado.'):format(targetGroup.name), 'success')
end)

-- Desconecta uma caixa do seu grupo
RegisterNetEvent('vp_newspaper:server:leaveSpeakerGroup', function(speakerId)
    local src = source
    if not speakerId then return end

    local gid, group = FindGroupBySpeaker(speakerId)
    if not gid then
        NotifyPlayer(src, 'Sua caixa não está em nenhum grupo!', 'inform')
        return
    end

    for i, sid in ipairs(group.speakerIds) do
        if sid == speakerId then table.remove(group.speakerIds, i); break end
    end

    -- Limpa groupId do áudio da caixa
    if SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId].groupId = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    end

    -- Dissolve grupo se vazio
    if #group.speakerIds == 0 then
        SpeakerGroups[gid] = nil
    end

    TriggerClientEvent('vp_newspaper:client:speakerGroupLeft', src, speakerId)
    NotifyPlayer(src, 'Caixa de som desconectada do grupo.', 'info')
end)

-- Líder toca música no grupo (sincroniza para todos os membros)
RegisterNetEvent('vp_newspaper:server:playGroupMusic', function(speakerId, url, timestamp)
    local src = source
    if not speakerId or type(url) ~= 'string' or #url < 6 or #url > 500 then return end

    local gid, group = FindGroupBySpeaker(speakerId)
    if not gid then
        NotifyPlayer(src, 'Sua caixa não está em nenhum grupo! Crie ou entre em um primeiro.', 'error')
        return
    end

    -- Apenas o líder pode controlar o áudio do grupo
    if group.leaderSrc ~= src then
        NotifyPlayer(src, 'Apenas o criador do grupo pode controlar o áudio!', 'error')
        return
    end

    local skipSeconds = math.max(0, tonumber(timestamp) or 0)
    group.isPlaying  = true
    group.url        = url:gsub('^%s*(.-)%s*$', '%1')
    group.startTime  = os.time() - skipSeconds
    group.elapsed    = skipSeconds
    group.isRadio    = false
    group.title      = 'Grupo: Música Sincronizada'

    SyncGroupToMembers(group)
    SaveSongToHistory(src, url, 'Grupo: Música Sincronizada')
    NotifyPlayer(src, ('▶ Grupo "%s": música iniciada para %d caixas!'):format(group.name, #group.speakerIds), 'success')
end)

-- Pausa/retoma o grupo
RegisterNetEvent('vp_newspaper:server:pauseGroupMusic', function(speakerId)
    local src = source
    if not speakerId then return end

    local gid, group = FindGroupBySpeaker(speakerId)
    if not gid or group.leaderSrc ~= src then return end

    group.isPlaying = not group.isPlaying
    SyncGroupToMembers(group)

    local msg = group.isPlaying and '▶ Grupo retomado.' or '⏸ Grupo pausado.'
    NotifyPlayer(src, msg, 'info')
end)

-- Para o grupo
RegisterNetEvent('vp_newspaper:server:stopGroupMusic', function(speakerId)
    local src = source
    if not speakerId then return end

    local gid, group = FindGroupBySpeaker(speakerId)
    if not gid or group.leaderSrc ~= src then return end

    group.isPlaying = false
    group.url       = nil
    SyncGroupToMembers(group)
    NotifyPlayer(src, '⏹ Grupo parado.', 'info')
end)

AddEventHandler('playerDropped', function()
    local src = source

    -- Limpa caixa carregada no ombro
    local carriedKey = 'carried_' .. tostring(src)
    if SpeakerAudioStates[carriedKey] then
        SpeakerAudioStates[carriedKey] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, carriedKey, nil)
    end

    -- BUG FIX: dissolve grupos onde o líder saiu, ou remove das listas de membros
    for gid, group in pairs(SpeakerGroups) do
        if group.leaderSrc == src then
            -- Líder saiu: dissolve o grupo e notifica membros remanescentes
            -- Primeiro limpa o groupId de todos os speakerAudioStates membros
            for _, sid in ipairs(group.speakerIds) do
                if SpeakerAudioStates[sid] then
                    SpeakerAudioStates[sid].groupId = nil
                    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, sid, SpeakerAudioStates[sid])
                end
            end
            -- Notifica o src de cada speaker membro (player que possuí essa caixa) que o grupo foi dissolvido
            local dissolvedMsg = ('Grupo "%s" dissolvido (líder saiu do servidor).'):format(group.name)
            -- Tentamos notificar membros cujo ownerSrc conhecemos
            local notifiedSrcs = {}
            for _, sid in ipairs(group.speakerIds) do
                local st = SpeakerAudioStates[sid]
                local ownerSrc = st and st.ownerSrc
                if ownerSrc and ownerSrc ~= src and not notifiedSrcs[ownerSrc] then
                    notifiedSrcs[ownerSrc] = true
                    TriggerClientEvent('vp_newspaper:client:speakerGroupLeft', ownerSrc, sid)
                    NotifyPlayer(ownerSrc, dissolvedMsg, 'error')
                end
            end
            SpeakerGroups[gid] = nil
        else
            -- Apenas remove as caixas do player dos membros do grupo
            for i = #group.speakerIds, 1, -1 do
                local sid = group.speakerIds[i]
                local st  = SpeakerAudioStates[sid]
                if st and st.ownerSrc == src then
                    table.remove(group.speakerIds, i)
                    if SpeakerAudioStates[sid] then
                        SpeakerAudioStates[sid].groupId = nil
                    end
                end
            end
            -- Dissolve grupo se ficou vazio sem o líder
            if #group.speakerIds == 0 then
                SpeakerGroups[gid] = nil
            end
        end
    end
end)

-- ==========================================================
-- 1. Loja de Caixas de Som (Rahe Speaker Shop)
-- ==========================================================

lib.callback.register('vp_newspaper:server:purchaseSpeaker', function(source, speakerType)
    local src = source
    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    local typeCfg = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    if not typeCfg or not typeCfg.price or not typeCfg.item then
        return false, 'Tipo de caixa inválido ou indisponível para venda!'
    end

    local price = typeCfg.price
    local hasEnough = false
    local paidMethod = nil

    if player.PlayerData and player.PlayerData.money then
        if player.PlayerData.money.cash and player.PlayerData.money.cash >= price then
            hasEnough = true
            paidMethod = 'cash'
        elseif player.PlayerData.money.bank and player.PlayerData.money.bank >= price then
            hasEnough = true
            paidMethod = 'bank'
        end
    end

    if not hasEnough then
        return false, ('Saldo insuficiente! Você precisa de $%d em dinheiro ou no banco.'):format(price)
    end

    local removed = false
    if player.Functions and player.Functions.RemoveMoney then
        removed = player.Functions.RemoveMoney(paidMethod, price, 'weazel-speaker-shop')
    end

    if not removed then
        return false, 'Falha ao processar pagamento!'
    end

    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local added = exports.ox_inventory:AddItem(src, typeCfg.item, 1)
        if not added then
            if player.Functions and player.Functions.AddMoney then
                player.Functions.AddMoney(paidMethod, price, 'weazel-speaker-refund')
            end
            return false, 'Seu inventário está cheio!'
        end
    elseif QBCore then
        local added = player.Functions.AddItem(typeCfg.item, 1)
        if not added then
            player.Functions.AddMoney(paidMethod, price, 'weazel-speaker-refund')
            return false, 'Inventário cheio!'
        end
    end

    SendDiscordLog(
        '🛒 COMPRA DE CAIXA DE SOM',
        ('O cidadão **%s** comprou **%s** por $%d (%s).'):format(
            GetPlayerName(src) or 'Jogador',
            typeCfg.label,
            price,
            paidMethod:upper()
        ),
        3066993
    )

    return true, typeCfg.label
end)

-- ==========================================================
-- 2. Fila de Músicas por Caixa de Som (Rahe Music Queue System)
-- ==========================================================

local SpeakerQueues = {} -- [speakerId] = { { url = string, title = string, addedBy = string }, ... }

local function PlayNextQueuedTrack(speakerId)
    if not SpeakerQueues[speakerId] or #SpeakerQueues[speakerId] == 0 then
        return false
    end

    local nextTrack = table.remove(SpeakerQueues[speakerId], 1)
    if not SpeakerAudioStates[speakerId] then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId }
    end

    SpeakerAudioStates[speakerId].isPlaying = true
    SpeakerAudioStates[speakerId].url = nextTrack.url
    SpeakerAudioStates[speakerId].startTime = os.time()
    SpeakerAudioStates[speakerId].elapsed = 0
    SpeakerAudioStates[speakerId].isRadio = false
    SpeakerAudioStates[speakerId].title = nextTrack.title

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, SpeakerAudioStates[speakerId])
    return true, nextTrack
end

RegisterNetEvent('vp_newspaper:server:addToSpeakerQueue', function(speakerId, url, title)
    local src = source
    if not speakerId or type(url) ~= 'string' or #url < 6 or #url > 500 then return end

    if not SpeakerQueues[speakerId] then
        SpeakerQueues[speakerId] = {}
    end

    if #SpeakerQueues[speakerId] >= 15 then
        NotifyPlayer(src, 'A fila desta caixa está cheia (máx 15 músicas)!', 'error')
        return
    end

    local cleanTitle = (type(title) == 'string' and #title > 0) and title:gsub('<[^>]*>', ''):sub(1, 60) or 'Música Enfileirada'

    table.insert(SpeakerQueues[speakerId], {
        url = url:gsub('^%s*(.-)%s*$', '%1'),
        title = cleanTitle,
        addedBy = GetPlayerName(src) or 'Anônimo'
    })

    NotifyPlayer(src, ('➕ Música "%s" adicionada à fila (Posição #%d)!'):format(cleanTitle, #SpeakerQueues[speakerId]), 'success')
end)

lib.callback.register('vp_newspaper:server:getSpeakerQueue', function(source, speakerId)
    return SpeakerQueues[speakerId] or {}
end)

RegisterNetEvent('vp_newspaper:server:removeQueueIndex', function(speakerId, index)
    local src = source
    if not speakerId or not index or not SpeakerQueues[speakerId] then return end
    index = tonumber(index)
    if index and SpeakerQueues[speakerId][index] then
        local removed = table.remove(SpeakerQueues[speakerId], index)
        NotifyPlayer(src, ('Faixa "%s" removida da fila.'):format(removed.title or 'Música'), 'info')
    end
end)

RegisterNetEvent('vp_newspaper:server:skipToNextQueuedSong', function(speakerId)
    local src = source
    local ok, track = PlayNextQueuedTrack(speakerId)
    if ok then
        NotifyPlayer(src, ('▶ Tocando próxima da fila: %s'):format(track.title), 'success')
    else
        NotifyPlayer(src, 'A fila de músicas desta caixa está vazia!', 'inform')
    end
end)

RegisterNetEvent('vp_newspaper:server:reportSpeakerTrackEnded', function(speakerId)
    if speakerId and SpeakerQueues[speakerId] and #SpeakerQueues[speakerId] > 0 then
        PlayNextQueuedTrack(speakerId)
    end
end)

-- ==========================================================
-- 3. Histórico de Músicas Tocadas (Rahe Playback History)
-- ==========================================================

lib.callback.register('vp_newspaper:server:getSpeakerHistory', function(source)
    local player = GetPlayer(source)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return {} end
    local cid = player.PlayerData.citizenid

    local rows = MySQL.query.await([[
        SELECT `id`, `url`, `title`, `is_favorite`, `played_at`
        FROM `newspaper_speaker_history`
        WHERE `citizenid` = ?
        ORDER BY `is_favorite` DESC, `played_at` DESC
        LIMIT 15
    ]], { cid })

    return rows or {}
end)

RegisterNetEvent('vp_newspaper:server:favoriteHistorySong', function(historyId)
    local src = source
    local player = GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end
    local cid = player.PlayerData.citizenid
    historyId = tonumber(historyId)
    if not historyId then return end

    MySQL.query('UPDATE `newspaper_speaker_history` SET `is_favorite` = 1 WHERE `id` = ? AND `citizenid` = ?', { historyId, cid })
    NotifyPlayer(src, '⭐ Música adicionada aos favoritos!', 'success')
end)

RegisterNetEvent('vp_newspaper:server:unfavoriteHistorySong', function(historyId)
    local src = source
    local player = GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end
    local cid = player.PlayerData.citizenid
    historyId = tonumber(historyId)
    if not historyId then return end

    MySQL.query('UPDATE `newspaper_speaker_history` SET `is_favorite` = 0 WHERE `id` = ? AND `citizenid` = ?', { historyId, cid })
    NotifyPlayer(src, 'Música removida dos favoritos.', 'info')
end)

RegisterNetEvent('vp_newspaper:server:deleteHistorySong', function(historyId)
    local src = source
    local player = GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end
    local cid = player.PlayerData.citizenid
    historyId = tonumber(historyId)
    if not historyId then return end

    MySQL.query('DELETE FROM `newspaper_speaker_history` WHERE `id` = ? AND `citizenid` = ?', { historyId, cid })
    NotifyPlayer(src, 'Música removida do seu histórico.', 'info')
end)

-- Renomear Caixa de Som (Rahe Rename Speaker)
RegisterNetEvent('vp_newspaper:server:renameSpeaker', function(speakerId, newName)
    local src = source
    if not speakerId or type(newName) ~= 'string' or #newName < 1 or #newName > 50 then return end
    local cleanName = newName:gsub('<[^>]*>', ''):sub(1, 40)

    local st = SpeakerAudioStates[speakerId]
    if not st then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false, ownerSrc = src }
        st = SpeakerAudioStates[speakerId]
    end

    local isOwner = (st.ownerSrc == src) or (speakerId == 'carried_' .. tostring(src))
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command') or (Config.General and Config.General.allowTestCommands)

    if not isOwner and not isAdmin then
        NotifyPlayer(src, 'Apenas o proprietário pode renomear a caixa!', 'error')
        return
    end

    st.customName = cleanName

    if st.isPermanent and st.permId then
        MySQL.query('UPDATE `newspaper_permanent_speakers` SET `name` = ? WHERE `id` = ?', { cleanName, st.permId })
        if PermanentSpeakers[st.permId] then
            PermanentSpeakers[st.permId].name = cleanName
            TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', -1, PermanentSpeakers)
        end
    end

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, st)
    NotifyPlayer(src, ('Nome da caixa alterado para: "%s"'):format(cleanName), 'success')
end)

-- ==========================================================
-- 4. Sistema de Permissões e Proteção por PIN (Rahe Permissions)
-- ==========================================================

lib.callback.register('vp_newspaper:server:validateSpeakerAccess', function(source, speakerId, inputPin)
    local src = source

    if IsPlayerAceAllowed(tostring(src), 'command') or (Config.General and Config.General.allowTestCommands) then
        return true
    end

    local st = SpeakerAudioStates[speakerId]
    if not st or not st.securityMode or st.securityMode == 'public' then
        return true
    end

    if st.ownerSrc == src or speakerId == ('carried_' .. tostring(src)) then
        return true
    end

    if st.securityMode == 'owner_only' then
        return false, 'Esta caixa de som está restrita exclusivamente ao proprietário!'
    end

    if st.securityMode == 'pin' then
        if not inputPin or tostring(inputPin) ~= tostring(st.pinCode) then
            return false, 'PIN de segurança incorreto!'
        end
        return true
    end

    return true
end)

RegisterNetEvent('vp_newspaper:server:setSpeakerSecurity', function(speakerId, mode, pin)
    local src = source
    if not speakerId then return end

    local st = SpeakerAudioStates[speakerId]
    if not st then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false, ownerSrc = src }
        st = SpeakerAudioStates[speakerId]
    end

    local isOwner = (st.ownerSrc == src) or (speakerId == 'carried_' .. tostring(src))
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command') or (Config.General and Config.General.allowTestCommands)

    if not isOwner and not isAdmin then
        NotifyPlayer(src, 'Apenas o dono da caixa de som pode alterar as permissões de acesso!', 'error')
        return
    end

    local validModes = { public = true, owner_only = true, pin = true }
    local chosenMode = validModes[mode] and mode or 'public'

    st.securityMode = chosenMode
    st.pinCode = (chosenMode == 'pin' and pin) and tostring(pin):sub(1, 8) or nil

    local modeLabels = {
        public = 'Público (Qualquer jogador próximo pode controlar)',
        owner_only = 'Privado (Apenas você pode controlar)',
        pin = ('Protegido por PIN (%s)'):format(st.pinCode or '****')
    }

    NotifyPlayer(src, ('🔒 Permissão da caixa atualizada:\n%s'):format(modeLabels[chosenMode]), 'success')
end)

-- ==========================================================
-- 5. Caixas Permanentes Salvas no Banco de Dados (Rahe Permanent)
-- ==========================================================

local PermanentSpeakers = {} -- [permId] = { id, coords, heading, speakerType, name, speakerKey }

local function LoadPermanentSpeakers()
    local rows = MySQL.query.await('SELECT * FROM `newspaper_permanent_speakers`', {})
    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            local c = json.decode(row.coords)
            if c and c.x and c.y and c.z then
                local permKey = 'perm_' .. tostring(row.id)
                SpeakerAudioStates[permKey] = {
                    speakerId = permKey,
                    isPlaying = false,
                    volume = row.volume or 0.8,
                    range = row.max_range or 35.0,
                    speakerTypeId = row.speaker_type or 'retro',
                    isPermanent = true,
                    permId = row.id,
                    name = row.name,
                    securityMode = row.security_mode or 'public',
                    pinCode = row.pin_code,
                    coords = vector3(c.x, c.y, c.z),
                    heading = row.heading or 0.0,
                }
                PermanentSpeakers[row.id] = {
                    id = row.id,
                    coords = vector3(c.x, c.y, c.z),
                    heading = row.heading or 0.0,
                    speakerType = row.speaker_type or 'retro',
                    name = row.name,
                    speakerKey = permKey
                }
            end
        end
        print(('^2[vp_newspaper] %d caixas permanentes carregadas do banco de dados.^7'):format(#rows))
        TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', -1, PermanentSpeakers)
    end
end

AddEventHandler('vp_newspaper:server:migrationsComplete', function()
    LoadPermanentSpeakers()
end)

CreateThread(function()
    Wait(3000)
    if DatabaseReady then
        LoadPermanentSpeakers()
    end
end)

RegisterNetEvent('vp_newspaper:server:requestPermanentSpeakers', function()
    local src = source
    TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', src, PermanentSpeakers)
end)

RegisterNetEvent('vp_newspaper:server:makeSpeakerPermanent', function(netId, customName)
    local src = source
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
        or IsPlayerAceAllowed(tostring(src), 'group.admin')
        or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isAdmin then
        NotifyPlayer(src, 'Apenas administradores podem transformar caixas em permanentes!', 'error')
        return
    end

    local groundSpeaker = ActiveGroundSpeakers[netId]
    if not groundSpeaker then
        NotifyPlayer(src, 'Caixa de som não encontrada no chão!', 'error')
        return
    end

    local name = (type(customName) == 'string' and #customName > 0) and customName:sub(1, 60) or 'Caixa Permanente'
    local speakerType = groundSpeaker.speakerType or 'retro'
    local typeCfg = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local maxRange = typeCfg and typeCfg.maxRange or 35.0
    local maxVolume = typeCfg and typeCfg.maxVolume or 1.0

    local coordsJson = json.encode({ x = groundSpeaker.coords.x, y = groundSpeaker.coords.y, z = groundSpeaker.coords.z })

    local insertId = MySQL.insert.await([[
        INSERT INTO `newspaper_permanent_speakers`
        (`speaker_type`, `coords`, `heading`, `volume`, `max_range`, `name`, `created_by`)
        VALUES (?, ?, 0.0, ?, ?, ?, ?)
    ]], { speakerType, coordsJson, maxVolume, maxRange, name, GetPlayerName(src) or 'Admin' })

    if insertId and insertId > 0 then
        ActiveGroundSpeakers[netId] = nil
        TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)

        local permKey = 'perm_' .. tostring(insertId)
        PermanentSpeakers[insertId] = {
            id = insertId,
            coords = groundSpeaker.coords,
            heading = 0.0,
            speakerType = speakerType,
            name = name,
            speakerKey = permKey
        }

        SpeakerAudioStates[permKey] = {
            speakerId = permKey,
            isPlaying = false,
            volume = maxVolume,
            range = maxRange,
            speakerTypeId = speakerType,
            isPermanent = true,
            permId = insertId,
            name = name,
            coords = groundSpeaker.coords,
            heading = 0.0,
        }

        TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', -1, PermanentSpeakers)
        NotifyPlayer(src, ('🏛 Caixa permanente "%s" salva com sucesso (ID: %d)!'):format(name, insertId), 'success')
    end
end)

-- ==========================================================
-- 6. Renomear Caixas de Som (Rahe Speaker Renaming)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:renameSpeaker', function(speakerId, newName)
    local src = source
    if not speakerId or type(newName) ~= 'string' then return end

    local cleanName = newName:gsub('^%s*(.-)%s*$', '%1'):sub(1, 60)
    if #cleanName == 0 then cleanName = 'Caixa de Som' end

    local st = SpeakerAudioStates[speakerId]
    if not st then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false, ownerSrc = src }
        st = SpeakerAudioStates[speakerId]
    end

    local isOwner = (st.ownerSrc == src) or (speakerId == 'carried_' .. tostring(src))
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command') or (Config.General and Config.General.allowTestCommands)

    if not isOwner and not isAdmin then
        NotifyPlayer(src, 'Apenas o dono ou um administrador pode renomear esta caixa!', 'error')
        return
    end

    st.name = cleanName

    -- Se for permanente, atualiza no banco de dados
    if speakerId:sub(1, 5) == 'perm_' then
        local permId = tonumber(speakerId:sub(6))
        if permId and PermanentSpeakers[permId] then
            PermanentSpeakers[permId].name = cleanName
            MySQL.update('UPDATE `newspaper_permanent_speakers` SET `name` = ? WHERE `id` = ?', { cleanName, permId })
            TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', -1, PermanentSpeakers)
        end
    end

    -- Se for no chão, atualiza na tabela de ground speakers
    if speakerId:sub(1, 7) == 'ground_' then
        local netId = tonumber(speakerId:sub(8))
        if netId and ActiveGroundSpeakers[netId] then
            ActiveGroundSpeakers[netId].name = cleanName
            TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)
        end
    end

    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, st)
    NotifyPlayer(src, ('🏷️ Caixa renomeada para: "%s"'):format(cleanName), 'success')
end)

-- ==========================================================
-- 7. Equalizador & Filtros Acústicos de Caixa (Rahe Audio EQ)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:setSpeakerEQ', function(speakerId, preset)
    local src = source
    if not speakerId or type(preset) ~= 'string' then return end

    local validPresets = { flat = true, bass = true, vocal = true, club = true, outdoor = true }
    if not validPresets[preset] then preset = 'flat' end

    local st = SpeakerAudioStates[speakerId]
    if not st then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false, ownerSrc = src }
        st = SpeakerAudioStates[speakerId]
    end

    st.eqPreset = preset
    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, st)
    NotifyPlayer(src, ('🎛️ Equalizador ajustado para: %s'):format(preset:upper()), 'info')
end)

-- ==========================================================
-- 8. Grupos de Caixas de Som (Rahe Speaker Groups Architecture)
-- ==========================================================

local SpeakerGroups = {} -- [groupId] = { id, name, connectCode, accessCode, ownerCid, isPlaying, url, startTime, paused, queue = {} }
local PlayerAccessedGroups = {} -- [src] = groupId

local function LoadSpeakerGroups()
    local rows = MySQL.query.await('SELECT * FROM `newspaper_speaker_groups`', {})
    if rows and #rows > 0 then
        for _, row in ipairs(rows) do
            SpeakerGroups[row.id] = {
                id = row.id,
                name = row.name,
                connectCode = row.connect_code,
                accessCode = row.access_code,
                ownerCid = row.owner_cid,
                isPlaying = false,
                url = nil,
                startTime = 0,
                paused = false,
                queue = {}
            }
        end
        print(('^2[vp_newspaper] %d grupos de caixas de som carregados do banco de dados.^7'):format(#rows))
        TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    end
end

CreateThread(function()
    Wait(4000)
    if DatabaseReady then
        LoadSpeakerGroups()
    end
end)

RegisterNetEvent('vp_newspaper:server:createSpeakerGroup', function(name, connectCode, accessCode)
    local src = source
    local player = GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end
    local cid = player.PlayerData.citizenid

    if type(name) ~= 'string' or type(connectCode) ~= 'string' or type(accessCode) ~= 'string' then
        NotifyPlayer(src, 'Dados inválidos para criação do grupo!', 'error')
        return
    end

    name = name:gsub('^%s*(.-)%s*$', '%1'):sub(1, 40)
    connectCode = connectCode:gsub('^%s*(.-)%s*$', '%1'):upper():sub(1, 20)
    accessCode = accessCode:gsub('^%s*(.-)%s*$', '%1'):sub(1, 20)

    if #name < 2 or #connectCode < 2 or #accessCode < 2 then
        NotifyPlayer(src, 'Preencha todos os campos do grupo com ao menos 2 caracteres!', 'error')
        return
    end

    -- Verifica se já existe connect_code idêntico
    for _, g in pairs(SpeakerGroups) do
        if g.connectCode == connectCode then
            NotifyPlayer(src, 'Este Código de Conexão já está em uso por outro grupo!', 'error')
            return
        end
    end

    local insertId = MySQL.insert.await([[
        INSERT INTO `newspaper_speaker_groups` (`name`, `connect_code`, `access_code`, `owner_cid`)
        VALUES (?, ?, ?, ?)
    ]], { name, connectCode, accessCode, cid })

    if insertId and insertId > 0 then
        SpeakerGroups[insertId] = {
            id = insertId,
            name = name,
            connectCode = connectCode,
            accessCode = accessCode,
            ownerCid = cid,
            isPlaying = false,
            url = nil,
            startTime = 0,
            paused = false,
            queue = {}
        }
        PlayerAccessedGroups[src] = insertId
        TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
        NotifyPlayer(src, ('🎉 Grupo de Caixas "%s" criado com sucesso!'):format(name), 'success')
        TriggerClientEvent('vp_newspaper:client:openSpeakerGroupMenu', src, SpeakerGroups[insertId])
    end
end)

RegisterNetEvent('vp_newspaper:server:accessSpeakerGroup', function(accessCode)
    local src = source
    if type(accessCode) ~= 'string' then return end
    accessCode = accessCode:gsub('^%s*(.-)%s*$', '%1')

    local targetGroup = nil
    for _, g in pairs(SpeakerGroups) do
        if g.accessCode == accessCode then
            targetGroup = g
            break
        end
    end

    if not targetGroup then
        NotifyPlayer(src, 'Nenhum grupo encontrado com este Código de Acesso!', 'error')
        return
    end

    PlayerAccessedGroups[src] = targetGroup.id
    NotifyPlayer(src, ('🔓 Conectado ao painel do grupo "%s"!'):format(targetGroup.name), 'success')
    TriggerClientEvent('vp_newspaper:client:openSpeakerGroupMenu', src, targetGroup)
end)

RegisterNetEvent('vp_newspaper:server:addToGroup', function(speakerId, connectCode)
    local src = source
    if not speakerId or type(connectCode) ~= 'string' then return end
    connectCode = connectCode:gsub('^%s*(.-)%s*$', '%1'):upper()

    local targetGroup = nil
    for _, g in pairs(SpeakerGroups) do
        if g.connectCode == connectCode then
            targetGroup = g
            break
        end
    end

    if not targetGroup then
        NotifyPlayer(src, 'Grupo não encontrado com este Código de Conexão!', 'error')
        return
    end

    local st = SpeakerAudioStates[speakerId]
    if not st then
        SpeakerAudioStates[speakerId] = { speakerId = speakerId, isPlaying = false, ownerSrc = src }
        st = SpeakerAudioStates[speakerId]
    end

    st.groupId = targetGroup.id
    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, st)
    NotifyPlayer(src, ('🔗 Caixa de som conectada ao grupo "%s"!'):format(targetGroup.name), 'success')
end)

RegisterNetEvent('vp_newspaper:server:removeFromGroup', function(speakerId)
    local src = source
    if not speakerId then return end

    local st = SpeakerAudioStates[speakerId]
    if st and st.groupId then
        st.groupId = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, st)
        NotifyPlayer(src, 'Caixa de som desconectada do grupo.', 'info')
    end
end)

RegisterNetEvent('vp_newspaper:server:playGroupMusic', function(groupId, url, timestamp)
    local src = source
    groupId = tonumber(groupId)
    local group = SpeakerGroups[groupId]
    if not group then return end

    if type(url) == 'string' then
        url = url:gsub('^%s*(.-)%s*$', '%1')
    end
    if not url or #url < 6 then return end

    local skip = math.max(0, tonumber(timestamp) or 0)
    group.isPlaying = true
    group.url = url
    group.startTime = os.time() - skip
    group.paused = false

    SaveSongToHistory(src, url, 'Música em Grupo: ' .. group.name)

    TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    NotifyPlayer(src, ('🎶 Música iniciada em todo o grupo "%s"!'):format(group.name), 'success')
end)

RegisterNetEvent('vp_newspaper:server:pauseResumeGroup', function(groupId)
    local src = source
    groupId = tonumber(groupId)
    local group = SpeakerGroups[groupId]
    if not group then return end

    group.paused = not group.paused
    if group.paused then
        group.pauseTime = os.time()
    else
        if group.pauseTime then
            group.startTime = group.startTime + (os.time() - group.pauseTime)
            group.pauseTime = nil
        end
    end

    TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    NotifyPlayer(src, group.paused and '⏸️ Grupo pausado.' or '▶️ Grupo retomado.', 'info')
end)

RegisterNetEvent('vp_newspaper:server:addToGroupQueue', function(groupId, url, title)
    local src = source
    groupId = tonumber(groupId)
    local group = SpeakerGroups[groupId]
    if not group then return end

    if type(url) == 'string' then
        url = url:gsub('^%s*(.-)%s*$', '%1')
    end
    if not url or #url < 6 then return end

    table.insert(group.queue, {
        url = url,
        title = (type(title) == 'string' and #title > 0) and title:sub(1, 80) or 'Música na Fila do Grupo',
        addedBy = GetPlayerName(src) or 'Anônimo'
    })

    TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    NotifyPlayer(src, '🎵 Música adicionada à fila do grupo!', 'success')
end)

RegisterNetEvent('vp_newspaper:server:nextGroupSong', function(groupId)
    local src = source
    groupId = tonumber(groupId)
    local group = SpeakerGroups[groupId]
    if not group then return end

    if #group.queue > 0 then
        local nextTrack = table.remove(group.queue, 1)
        group.isPlaying = true
        group.url = nextTrack.url
        group.startTime = os.time()
        group.paused = false
        TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
        NotifyPlayer(src, ('⏭️ Próxima música do grupo: %s'):format(nextTrack.title), 'success')
    else
        group.isPlaying = false
        group.url = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
        NotifyPlayer(src, 'A fila do grupo acabou.', 'info')
    end
end)

-- ==========================================================
-- 9. Painel de Controle de Administrador (/speakersadmin & /killallspeakers)
-- ==========================================================

lib.callback.register('vp_newspaper:server:getAdminSpeakersList', function(source)
    local src = source
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
        or IsPlayerAceAllowed(tostring(src), 'group.admin')
        or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isAdmin then return false, 'Permissão insuficiente' end

    local list = {}

    -- 1. Caixas no chão
    for netId, gData in pairs(ActiveGroundSpeakers) do
        local key = 'ground_' .. tostring(netId)
        local audio = SpeakerAudioStates[key]
        table.insert(list, {
            speakerId = key,
            type = 'ground',
            speakerType = gData.speakerType or 'retro',
            name = gData.name or ('Caixa de Chão (NetID %d)'):format(netId),
            coords = gData.coords,
            isPlaying = audio and audio.isPlaying or false,
            url = audio and audio.url or nil,
            volume = audio and audio.volume or 0.8,
            range = audio and audio.range or 25.0,
            netId = netId
        })
    end

    -- 2. Caixas Permanentes
    for permId, pData in pairs(PermanentSpeakers) do
        local key = 'perm_' .. tostring(permId)
        local audio = SpeakerAudioStates[key]
        table.insert(list, {
            speakerId = key,
            type = 'permanent',
            speakerType = pData.speakerType or 'retro',
            name = pData.name or ('Permanente #%d'):format(permId),
            coords = pData.coords,
            isPlaying = audio and audio.isPlaying or false,
            url = audio and audio.url or nil,
            volume = audio and audio.volume or 0.8,
            range = audio and audio.range or 35.0,
            permId = permId
        })
    end

    -- 3. Caixas nos Ombros
    for key, audio in pairs(SpeakerAudioStates) do
        if key:sub(1, 8) == 'carried_' then
            local plySrc = tonumber(key:sub(9))
            local plyPed = plySrc and GetPlayerPed(plySrc)
            local coords = (plyPed and DoesEntityExist(plyPed)) and GetEntityCoords(plyPed) or vector3(0,0,0)
            local plyName = (plySrc and GetPlayerName(plySrc)) or 'Desconhecido'
            table.insert(list, {
                speakerId = key,
                type = 'carried',
                speakerType = audio.speakerTypeId or 'retro',
                name = ('No Ombro de %s (ID %s)'):format(plyName, tostring(plySrc)),
                coords = coords,
                isPlaying = audio.isPlaying or false,
                url = audio.url or nil,
                volume = audio.volume or 0.8,
                range = audio.range or 25.0,
                playerSource = plySrc
            })
        end
    end

    return true, list
end)

RegisterNetEvent('vp_newspaper:server:adminDeleteSpeaker', function(speakerId)
    local src = source
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
        or IsPlayerAceAllowed(tostring(src), 'group.admin')
        or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isAdmin or not speakerId then return end

    if speakerId:sub(1, 5) == 'perm_' then
        local permId = tonumber(speakerId:sub(6))
        if permId then
            MySQL.query.await('DELETE FROM `newspaper_permanent_speakers` WHERE `id` = ?', { permId })
            PermanentSpeakers[permId] = nil
            TriggerClientEvent('vp_newspaper:client:syncPermanentSpeakers', -1, PermanentSpeakers)
        end
    elseif speakerId:sub(1, 7) == 'ground_' then
        local netId = tonumber(speakerId:sub(8))
        if netId then
            ActiveGroundSpeakers[netId] = nil
            TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, ActiveGroundSpeakers)
        end
    end

    SpeakerAudioStates[speakerId] = nil
    TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, speakerId, nil)
    NotifyPlayer(src, ('🗑️ Caixa "%s" deletada pelo Administrador.'):format(speakerId), 'success')
end)

RegisterNetEvent('vp_newspaper:server:adminKillAllSpeakers', function()
    local src = source
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')
        or IsPlayerAceAllowed(tostring(src), 'group.admin')
        or (Config.General and (Config.General.debugs or Config.General.allowTestCommands))

    if not isAdmin then return end

    for spId, _ in pairs(SpeakerAudioStates) do
        SpeakerAudioStates[spId] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, spId, nil)
    end

    for _, g in pairs(SpeakerGroups) do
        g.isPlaying = false
        g.url = nil
    end
    TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    TriggerClientEvent('vp_newspaper:client:killAllSpeakersAudio', -1)

    print(('^1[vp_newspaper] ADMIN %s EXECUTOU KILL-ALL EM TODOS OS SONS DE CAIXA!^7'):format(GetPlayerName(src) or 'Console'))
    NotifyPlayer(src, '🛑 Todos os sons e caixas ativas foram silenciados imediatamente!', 'error')
end)

RegisterCommand('killallspeakers', function(source)
    local src = source
    if src ~= 0 then
        local isAdmin = IsPlayerAceAllowed(tostring(src), 'command') or IsPlayerAceAllowed(tostring(src), 'group.admin')
        if not isAdmin then
            NotifyPlayer(src, 'Você não tem permissão para usar este comando.', 'error')
            return
        end
    end

    for spId, _ in pairs(SpeakerAudioStates) do
        SpeakerAudioStates[spId] = nil
        TriggerClientEvent('vp_newspaper:client:syncSpeakerAudio', -1, spId, nil)
    end

    for _, g in pairs(SpeakerGroups) do
        g.isPlaying = false
        g.url = nil
    end
    TriggerClientEvent('vp_newspaper:client:syncSpeakerGroups', -1, SpeakerGroups)
    TriggerClientEvent('vp_newspaper:client:killAllSpeakersAudio', -1)

    print('^1[vp_newspaper] KILL-ALL SPEAKERS EXECUTADO COM SUCESSO!^7')
end, false)

-- Limpeza ao parar o resource
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(AttachedVehicleSpeakers) do
        local veh = NetworkGetEntityFromNetworkId(netId)
        if veh and DoesEntityExist(veh) then
            Entity(veh).state:set('weazelVehicleSpeaker', nil, true)
        end
    end
    AttachedVehicleSpeakers = {}
    ActiveGroundSpeakers = {}
    PermanentSpeakers = {}
    SpeakerAudioStates = {}
    SpeakerQueues = {}
    SpeakerGroups = {}
    PlayerAccessedGroups = {}
end)
