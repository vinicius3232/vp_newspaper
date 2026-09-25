-- ==========================================================
-- vp_newspaper: Weazel Radio 98.5 FM & Unified Speaker System
-- Completely Absorbed from Rahe Speakers & Senora Signalworks
-- ==========================================================

local currentStation = nil
local isVehicleRadioOn = false
local isHeadphonesOn = false
local userVolume = 0.65
local ActiveGroundSpeakers = {} -- [netId] = { coords = vector3, owner = src }
local AttachedVehicleSpeakerProps = {} -- [vehNetId] = propEntity
local currentPlayingSource = nil -- 'vehicle' | 'headphones' | 'carried' | 'ground_speaker' | 'carried_other' | 'veh_speaker' | nil

-- Estado de carregamento manual da caixa de som (Boombox Carry)
local isCarryingBoombox = false
local carriedBoomboxProp = nil
local isBoomboxMuted = true -- Inicia desligada/silenciada por padrão
local currentSpeakerType = 'retro' -- Tipo ativo ao carregar: 'retro'|'vibe'|'beat'|'blast'

-- Estado local dos grupos de som
local LocalGroupState = nil -- { groupId, name, connectCode, isLeader }
local currentSpeakerUnlockedPins = {} -- [speakerId] = pin
local PermanentSpeakers = {} -- [permId] = { id, coords, heading, speakerType, name }
local SpawnedPermanentProps = {} -- [permId] = entity
local isPlacingSpeakerPreview = false

local ATTACH_CONFIGS = {
    trunk = {
        bone = 'boot',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -1.85, 0.2),
        rot = vector3(0.0, 0.0, 0.0)
    },
    roof = {
        bone = 'roof',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -0.2, 0.85),
        rot = vector3(0.0, 0.0, 0.0)
    },
    bed = {
        bone = 'bodyshell',
        fallbackBone = 'bodyshell',
        offset = vector3(0.0, -1.3, 0.3),
        rot = vector3(0.0, 0.0, 0.0)
    }
}

-- ==========================================================
-- Sincronização de Estado com o Servidor (Broadcasting & Speakers)
-- ==========================================================

local LocalSpeakersAudio = {}
local currentPlayingUrl = nil

RegisterNetEvent('vp_newspaper:client:syncRadioState', function(stationData)
    currentStation = stationData
    UpdateRadioPlayback()
end)

RegisterNetEvent('vp_newspaper:client:syncGroundSpeakers', function(speakers)
    ActiveGroundSpeakers = speakers or {}
    UpdateRadioPlayback()
end)

RegisterNetEvent('vp_newspaper:client:syncSpeakerAudio', function(speakerId, speakerData)
    if not speakerId then return end
    if speakerData then
        speakerData.localReceivedTimer = GetGameTimer()
    end
    LocalSpeakersAudio[speakerId] = speakerData
    UpdateRadioPlayback()
end)

local SpeakerGroups = {}

RegisterNetEvent('vp_newspaper:client:syncSpeakerGroups', function(groups)
    SpeakerGroups = groups or {}
    UpdateRadioPlayback()
end)

RegisterNetEvent('vp_newspaper:client:killAllSpeakersAudio', function()
    LocalSpeakersAudio = {}
    currentPlayingSource = nil
    currentPlayingUrl = nil
    SendNUIMessage({ action = 'stopRadio' })
    lib.notify({ title = 'Áudio Global', description = 'Todos os sons de caixas foram silenciados.', type = 'error' })
end)

RegisterNetEvent('vp_newspaper:client:syncAllSpeakersAudio', function(speakers)
    local now = GetGameTimer()
    if speakers then
        for _, spk in pairs(speakers) do
            if spk then spk.localReceivedTimer = now end
        end
    end
    LocalSpeakersAudio = speakers or {}
    UpdateRadioPlayback()
end)

CreateThread(function()
    Wait(2000)
    TriggerServerEvent('vp_newspaper:server:requestRadioState')
end)

RegisterNUICallback('radioTrackEnded', function(data, cb)
    if currentPlayingSource == 'headphones' or currentPlayingSource == 'vehicle_dash' then
        TriggerServerEvent('vp_newspaper:server:reportTrackEnded')
    elseif currentPlayingSource then
        TriggerServerEvent('vp_newspaper:server:reportSpeakerTrackEnded', currentPlayingSource)
    end
    cb('ok')
end)

---Calcula o tempo decorrido de uma caixa de som no client sem acessar o global os
---@param speaker table
---@return number
local function GetSpeakerElapsedTime(speaker)
    if not speaker then return 0 end
    local baseElapsed = speaker.elapsed or 0
    if speaker.startTime and speaker.startTime > 0 then
        local cloudTime = GetCloudTimeAsInt()
        if cloudTime and cloudTime > 0 and cloudTime >= speaker.startTime then
            return cloudTime - speaker.startTime
        end
    end
    if speaker.localReceivedTimer then
        local deltaSec = math.floor((GetGameTimer() - speaker.localReceivedTimer) / 1000)
        return math.max(0, baseElapsed + deltaSec)
    end
    return math.max(0, baseElapsed)
end

-- ==========================================================
-- Gerenciamento de Reprodução de Áudio Local (NUI 3D Multi-Speaker)
-- ==========================================================

function UpdateRadioPlayback()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local bestVolume = 0.0
    local bestUrl = nil
    local bestStartTime = 0
    local bestSourceId = nil
    local bestPreset = 'flat'
    local myServerId = GetPlayerServerId(PlayerId())

    -- 1. Fones de Ouvido (Prioridade Pessoal Máxima: Weazel Radio 98.5 FM)
    if isHeadphonesOn and currentStation and currentStation.isPlaying and currentStation.currentTrack then
        bestVolume = userVolume
        bestUrl = currentStation.currentTrack.url
        bestStartTime = currentStation.elapsed or 0
        bestSourceId = 'headphones'
        bestPreset = 'broadcast'

    else
        -- 2. Checa todas as caixas de som ativas (Ombro, Chão, Veículos ou Grupos)
        for speakerId, speaker in pairs(LocalSpeakersAudio) do
            if speaker then
                local sUrl = nil
                local sStart = 0
                local isPlaying = speaker.isPlaying

                -- Resolução de Áudio em Grupo (Rahe Speaker Groups)
                if speaker.groupId and SpeakerGroups[speaker.groupId] then
                    local grp = SpeakerGroups[speaker.groupId]
                    if grp.isPlaying and not grp.paused and grp.url then
                        isPlaying = true
                        sUrl = grp.url
                        local cloudTime = GetCloudTimeAsInt() or 0
                        sStart = math.max(0, cloudTime - (grp.startTime or cloudTime))
                    else
                        isPlaying = false
                    end
                elseif speaker.isRadio then
                    if currentStation and currentStation.isPlaying and currentStation.currentTrack then
                        sUrl = currentStation.currentTrack.url
                        sStart = currentStation.elapsed or 0
                    end
                else
                    sUrl = speaker.url
                    sStart = GetSpeakerElapsedTime(speaker)
                end

                if isPlaying and sUrl then
                    local sCoords = nil
                    local sDist = 999.0

                    -- A. Caixa no ombro de algum jogador
                    if speakerId:sub(1, 8) == 'carried_' then
                        local src = tonumber(speakerId:sub(9))
                        if src == myServerId then
                            sCoords = pCoords
                            sDist = 0.0
                        else
                            local ply = GetPlayerFromServerId(src)
                            if ply and ply ~= -1 then
                                local targetPed = GetPlayerPed(ply)
                                if DoesEntityExist(targetPed) then
                                    sCoords = GetEntityCoords(targetPed)
                                    sDist = #(pCoords - sCoords)
                                end
                            end
                        end

                    -- B. Caixa de som no chão
                    elseif speakerId:sub(1, 7) == 'ground_' then
                        local netId = tonumber(speakerId:sub(8))
                        if ActiveGroundSpeakers[netId] then
                            sCoords = ActiveGroundSpeakers[netId].coords
                            sDist = #(pCoords - sCoords)
                        elseif NetworkDoesNetworkIdExist(netId) then
                            local ent = NetworkGetEntityFromNetworkId(netId)
                            if DoesEntityExist(ent) then
                                sCoords = GetEntityCoords(ent)
                                sDist = #(pCoords - sCoords)
                            end
                        end

                    -- C. Caixa de som instalada em veículo
                    elseif speakerId:sub(1, 4) == 'veh_' then
                        local vehNetId = tonumber(speakerId:sub(5))
                        if NetworkDoesNetworkIdExist(vehNetId) then
                            local v = NetworkGetEntityFromNetworkId(vehNetId)
                            if DoesEntityExist(v) then
                                sCoords = GetEntityCoords(v)
                                sDist = #(pCoords - sCoords)
                            end
                        end

                    -- D. Caixa de som permanente salva no banco
                    elseif speakerId:sub(1, 5) == 'perm_' then
                        if speaker.coords then
                            sCoords = vector3(speaker.coords.x, speaker.coords.y, speaker.coords.z)
                            sDist = #(pCoords - sCoords)
                        end
                    end

                    local maxRange = speaker.range or 25.0
                    if sCoords and sDist <= maxRange then
                        local distFactor = math.max(0.0, 1.0 - (sDist / maxRange))
                        local calcVol = (speaker.volume or 0.8) * userVolume * (distFactor * distFactor)
                        if calcVol > bestVolume then
                            bestVolume = calcVol
                            bestUrl = sUrl
                            bestStartTime = sStart
                            bestSourceId = speakerId
                            bestPreset = speaker.eqPreset or 'flat'
                        end
                    end
                end
            end
        end

        -- 3. Rádio Veicular Ativo no Painel (Weazel FM nativo do carro)
        if not bestSourceId and isVehicleRadioOn and IsPedInAnyVehicle(ped, false) then
            if currentStation and currentStation.isPlaying and currentStation.currentTrack then
                bestVolume = userVolume
                bestUrl = currentStation.currentTrack.url
                bestStartTime = currentStation.elapsed or 0
                bestSourceId = 'vehicle_dash'
                bestPreset = 'broadcast'
            end
        end
    end

    -- 4. Oclusão Acústica Veicular (Som Abafado dentro de Veículo Fechado)
    if bestSourceId and bestSourceId ~= 'headphones' and bestSourceId ~= 'vehicle_dash' and IsPedInAnyVehicle(ped, false) then
        local currentVeh = GetVehiclePedIsIn(ped, false)
        local isSameVehSpeaker = (bestSourceId:sub(1, 4) == 'veh_' and tonumber(bestSourceId:sub(5)) == VehToNet(currentVeh))
        if not isSameVehSpeaker then
            local vehClass = GetVehicleClass(currentVeh)
            -- Motos (8) e Bicicletas (13) não possuem cabine fechada
            if vehClass ~= 8 and vehClass ~= 13 then
                bestVolume = bestVolume * 0.35
                bestPreset = 'vocal'
            end
        end
    end

    -- Aplica ao subsistema de áudio NUI
    if bestSourceId and bestUrl and bestVolume > 0.005 then
        if currentPlayingSource ~= bestSourceId or currentPlayingUrl ~= bestUrl then
            currentPlayingSource = bestSourceId
            currentPlayingUrl = bestUrl
            SendNUIMessage({
                action = 'playRadio',
                url = bestUrl,
                startTime = bestStartTime,
                volume = bestVolume,
                resource = GetCurrentResourceName()
            })
            SendNUIMessage({
                action = 'setEQ',
                preset = bestPreset
            })
        else
            SendNUIMessage({
                action = 'setVolume',
                volume = bestVolume
            })
        end
    else
        if currentPlayingSource then
            SendNUIMessage({ action = 'stopRadio' })
            currentPlayingSource = nil
            currentPlayingUrl = nil
        end
    end
end

-- Loop de cálculo de áudio 3D escalonado (Adaptive Ticking para Resmon 0.00ms idle)
CreateThread(function()
    while true do
        local sleep = 1200 -- Fast path: repouso profundo

        if isHeadphonesOn or isCarryingBoombox or isVehicleRadioOn then
            sleep = 250
            UpdateRadioPlayback()
        elseif next(LocalSpeakersAudio) then
            sleep = 300
            UpdateRadioPlayback()
        else
            if currentPlayingSource then
                UpdateRadioPlayback()
            end
            sleep = 1500
        end

        Wait(sleep)
    end
end)

-- ==========================================================
-- Interceptação de Plantão Urgente (Breaking News)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:radioAttenuate', function(factor)
    SendNUIMessage({
        action = 'attenuate',
        factor = factor or 0.15
    })
end)

RegisterNetEvent('vp_newspaper:client:radioRestoreVolume', function()
    SendNUIMessage({
        action = 'restoreVolume'
    })
end)

-- ==========================================================
-- Carregamento Físico de Caixa de Som (Rahe Carry System)
-- ==========================================================

function StartCarryingBoombox(speakerType)
    if isCarryingBoombox then return end

    -- Resolve a config do tipo de caixa (fallback: retro)
    speakerType = speakerType or currentSpeakerType or 'retro'
    local typeData = (Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType])
        or { model = joaat('prop_boombox_01'), bone = 57005, attachOffset = vector3(0.27, 0.0, 0.0), attachRot = vector3(0.0, 263.0, 58.0), carryType = 'shoulder', eqPreset = 'broadcast' }

    currentSpeakerType = speakerType

    local ped = PlayerPedId()
    local modelHash = typeData.model or joaat('prop_boombox_01')

    -- Animações por carryType
    local animDict, animName, animFlag
    if typeData.carryType == 'box_carry' then
        -- Carry de duas mãos: anim válida no GTA V base sem DLC
        -- (o dict 'anim@heists@box_carry@' não existe no base; usando ornate_bank hold_2hh)
        animDict = 'anim@heists@ornate_bank@'
        animName = 'hold_2hh'
        animFlag = 49
    else
        -- shoulder: boombox clássico (mão direita)
        animDict = 'move_weapon@jerrycan@generic'
        animName = 'idle'
        animFlag = 49
    end

    lib.requestModel(modelHash, 5000)
    lib.requestAnimDict(animDict, 5000)

    local coords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(prop, false, false)

    -- Acopla no osso correto com offset/rot do tipo
    local boneIndex = GetPedBoneIndex(ped, typeData.bone or 57005)
    local off = typeData.attachOffset or vector3(0.27, 0.0, 0.0)
    local rot = typeData.attachRot    or vector3(0.0, 263.0, 58.0)

    AttachEntityToEntity(
        prop, ped, boneIndex,
        off.x, off.y, off.z,
        rot.x, rot.y, rot.z,
        true, true, false, true, 1, true
    )

    isCarryingBoombox = true
    carriedBoomboxProp = prop
    SetModelAsNoLongerNeeded(modelHash)

    local myServerId = GetPlayerServerId(PlayerId())
    local carriedSpeakerKey = 'carried_' .. tostring(myServerId)

    LocalPlayer.state:set('weazelCarryingRadio', true, true)
    TaskPlayAnim(ped, animDict, animName, 3.0, 3.0, -1, animFlag, 0, false, false, false)

    -- Aplica o preset EQ do tipo imediatamente
    if typeData.eqPreset then
        SendNUIMessage({ action = 'setEQ', preset = typeData.eqPreset })
    end

    UpdateRadioPlayback()

    local typeCfg = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local typeLabel = typeCfg and typeCfg.label or 'Caixa de Som'

    lib.showTextUI(('[M] Controle de Som (%s) | [E] Chão | [G] Carro | [X] Guardar'):format(typeLabel), {
        position = 'left-center',
        icon = 'music'
    })

    -- Thread de controle de teclas do carregador
    CreateThread(function()
        while isCarryingBoombox do
            Wait(0)
            local p = PlayerPedId()

            if not IsEntityPlayingAnim(p, animDict, animName, 3) then
                TaskPlayAnim(p, animDict, animName, 3.0, 3.0, -1, animFlag, 0, false, false, false)
            end

            -- [M] Controle de Som da Caixa
            if IsControlJustPressed(0, 244) then
                OpenSpeakerControlMenu(carriedSpeakerKey, 'carried')

            -- [E] Colocar no chão
            elseif IsControlJustPressed(0, 38) then
                StopCarryingBoombox()
                PlaceGroundRadio()
                break

            -- [G] Instalar no veículo próximo
            elseif IsControlJustPressed(0, 47) then
                local pCoords = GetEntityCoords(p)
                local veh = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 4.0, 0, 71)
                if veh and veh ~= 0 then
                    StopCarryingBoombox()
                    OpenInstallSpeakerMenu(veh)
                else
                    lib.notify({ title = 'Som Veicular', description = 'Nenhum veículo próximo para acoplar!', type = 'error' })
                end
                break

            -- [X] Guardar na mochila
            elseif IsControlJustPressed(0, 73) then
                StopCarryingBoombox()
                TriggerServerEvent('vp_newspaper:server:clearSpeakerAudio', carriedSpeakerKey)
                lib.notify({ title = 'Caixa de Som', description = 'Caixa guardada.', type = 'inform' })
                break
            end  -- fim do bloco if/elseif de teclas
        end      -- fim do while
    end)         -- fim do CreateThread
end              -- fim de StartCarryingBoombox

function StopCarryingBoombox()
    if not isCarryingBoombox then return end
    isCarryingBoombox = false
    LocalPlayer.state:set('weazelCarryingRadio', false, true)
    lib.hideTextUI()

    local ped = PlayerPedId()
    ClearPedTasks(ped)

    if carriedBoomboxProp and DoesEntityExist(carriedBoomboxProp) then
        DetachEntity(carriedBoomboxProp, true, true)
        DeleteEntity(carriedBoomboxProp)
    end
    carriedBoomboxProp = nil
    UpdateRadioPlayback()
end

-- ==========================================================
-- Acoplamento Veicular (Rahe Vehicle Audio System)
-- ==========================================================

local function AttachSpeakerProp(veh, vehNetId, pointName, speakerType)
    if AttachedVehicleSpeakerProps[vehNetId] and DoesEntityExist(AttachedVehicleSpeakerProps[vehNetId]) then
        return
    end

    local cfg = ATTACH_CONFIGS[pointName] or ATTACH_CONFIGS.trunk
    speakerType = speakerType or 'retro'
    local typeData = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local propModel = (typeData and typeData.model) or (Config.General.Radio and Config.General.Radio.portableProp) or joaat('prop_boombox_01')

    lib.requestModel(propModel, 5000)

    local coords = GetEntityCoords(veh)
    local prop = CreateObject(propModel, coords.x, coords.y, coords.z, false, false, false)
    SetEntityCollision(prop, false, false)

    local boneIdx = GetEntityBoneIndexByName(veh, cfg.bone)
    if boneIdx == -1 then
        boneIdx = GetEntityBoneIndexByName(veh, cfg.fallbackBone)
    end
    if boneIdx == -1 then boneIdx = 0 end

    AttachEntityToEntity(
        prop, veh, boneIdx,
        cfg.offset.x, cfg.offset.y, cfg.offset.z,
        cfg.rot.x, cfg.rot.y, cfg.rot.z,
        false, false, false, false, 2, true
    )

    SetModelAsNoLongerNeeded(propModel)
    AttachedVehicleSpeakerProps[vehNetId] = prop
    UpdateRadioPlayback()
end

local function DetachSpeakerProp(vehNetId)
    local prop = AttachedVehicleSpeakerProps[vehNetId]
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    AttachedVehicleSpeakerProps[vehNetId] = nil
    UpdateRadioPlayback()
end

function OpenInstallSpeakerMenu(veh)
    local vehNetId = NetworkGetNetworkIdFromEntity(veh)
    local hasSpeaker = Entity(veh).state.weazelVehicleSpeaker ~= nil

    if hasSpeaker then
        lib.registerContext({
            id = 'weazel_vehicle_speaker_manage',
            title = 'Sistema de Som Veicular',
            options = {
                {
                    title = 'Controlar Caixa de Som',
                    description = 'Tocar YouTube, pausar, regular volume/alcance ou sintonizar rádio',
                    icon = 'music',
                    onSelect = function()
                        OpenSpeakerControlMenu('veh_' .. tostring(vehNetId), 'vehicle')
                    end
                },
                {
                    title = 'Desinstalar Caixa de Som',
                    description = 'Remove o equipamento e guarda na mochila',
                    icon = 'box-archive',
                    onSelect = function()
                        local ok, err = lib.callback.await('vp_newspaper:server:detachSpeakerFromVehicle', false, vehNetId)
                        if ok then
                            lib.notify({ title = 'Som Veicular', description = 'Sistema de som desinstalado!', type = 'success' })
                        else
                            lib.notify({ title = 'Som Veicular', description = err or 'Falha ao desinstalar!', type = 'error' })
                        end
                    end
                }
            }
        })
        lib.showContext('weazel_vehicle_speaker_manage')
        return
    end

    lib.registerContext({
        id = 'weazel_vehicle_speaker_install',
        title = 'Instalar Som no Veículo',
        options = {
            {
                title = 'Instalar no Porta-Malas / Traseira',
                description = 'Ideal para som automotivo e encontros',
                icon = 'car-rear',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'trunk')
                end
            },
            {
                title = 'Instalar no Teto / Rack',
                description = 'Ideal para utilitários e vans',
                icon = 'roof',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'roof')
                end
            },
            {
                title = 'Instalar na Caçamba',
                description = 'Ideal para caminhonetes e pick-ups',
                icon = 'truck-pickup',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'bed')
                end
            }
        }
    })
    lib.showContext('weazel_vehicle_speaker_install')
end

function InstallSpeakerAction(veh, vehNetId, point)
    TaskTurnPedToFaceEntity(PlayerPedId(), veh, 1000)
    Wait(600)

    local success = lib.progressBar({
        duration = 4000,
        label = 'Instalando sistema de som veicular...',
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
        lib.notify({ title = 'Som Veicular', description = 'Instalação cancelada.', type = 'inform' })
        return
    end

    local ok, res = lib.callback.await('vp_newspaper:server:attachSpeakerToVehicle', false, vehNetId, point, currentSpeakerType)
    if ok then
        lib.notify({
            title = '🔊 Som Veicular Instalado',
            description = 'Caixa acoplada com sucesso! Controle pelo /weazelradio.',
            type = 'success'
        })
    else
        lib.notify({
            title = 'Falha na Instalação',
            description = res or 'Não foi possível fixar o som.',
            type = 'error'
        })
    end
end

RegisterNetEvent('vp_newspaper:client:syncVehicleSpeaker', function(vehNetId, speakerData)
    local veh = NetworkDoesNetworkIdExist(vehNetId) and NetworkGetEntityFromNetworkId(vehNetId) or nil
    if not veh or not DoesEntityExist(veh) then return end

    if speakerData then
        AttachSpeakerProp(veh, vehNetId, speakerData.point, speakerData.speakerType)
    else
        DetachSpeakerProp(vehNetId)
    end
end)

AddStateBagChangeHandler('weazelVehicleSpeaker', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    local vehNetId = NetworkGetNetworkIdFromEntity(entity)
    if value then
        AttachSpeakerProp(entity, vehNetId, value.point)
    else
        DetachSpeakerProp(vehNetId)
    end
end)

-- ox_target global em veículos
CreateThread(function()
    if not Config.UseOxTarget then return end

    exports.ox_target:addGlobalVehicle({
        {
            name = 'vp_newspaper_vehicle_speaker',
            icon = 'fa-solid fa-volume-high',
            label = 'Sistema de Som Veicular',
            canInteract = function(entity, distance, coords, name)
                if distance > 3.5 then return false end
                local hasSpeaker = Entity(entity).state.weazelVehicleSpeaker ~= nil
                if hasSpeaker then return true end

                if Config.UseOxInventory then
                    local count = exports.ox_inventory:GetItemCount('radio_portable')
                    return count and count > 0
                end
                return true
            end,
            onSelect = function(data)
                OpenInstallSpeakerMenu(data.entity)
            end
        }
    })

    -- Constrói lista de todos os modelos de speaker para registrar interações de chão
    local allSpeakerModels = {}
    -- Inclui o prop legado primeiro
    local legacyProp = Config.General.Radio and Config.General.Radio.portableProp or joaat('prop_boombox_01')
    allSpeakerModels[#allSpeakerModels + 1] = legacyProp

    if Config.General.SpeakerTypes then
        for _, typeData in pairs(Config.General.SpeakerTypes) do
            if typeData.model then
                -- Evita duplicata
                local alreadyIn = false
                for _, m in ipairs(allSpeakerModels) do
                    if m == typeData.model then alreadyIn = true; break end
                end
                if not alreadyIn then
                    allSpeakerModels[#allSpeakerModels + 1] = typeData.model
                end
            end
        end
    end

    local groundInteractions = {
        {
            name = 'vp_newspaper_control_ground_speaker',
            icon = 'fa-solid fa-music',
            label = 'Controlar Caixa de Som',
            distance = 3.0,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                OpenSpeakerControlMenu('ground_' .. tostring(netId), 'ground')
            end
        },
        {
            name = 'vp_newspaper_carry_ground_speaker',
            icon = 'fa-solid fa-person-walking',
            label = 'Pegar no Ombro',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name)
                return distance <= 2.5 and not isCarryingBoombox
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                CarryGroundSpeakerToShoulder(netId, data.entity)
            end
        },
        {
            name = 'vp_newspaper_pickup_ground_speaker',
            icon = 'fa-solid fa-box-archive',
            label = 'Recolher para a Mochila',
            distance = 2.5,
            canInteract = function(entity, distance, coords, name)
                return distance <= 2.5 and not isCarryingBoombox
            end,
            onSelect = function(data)
                local netId = NetworkGetNetworkIdFromEntity(data.entity)
                PickupGroundSpeaker(netId, data.entity)
            end
        }
    }

    -- Registra as interações para cada modelo de speaker
    for _, modelHash in ipairs(allSpeakerModels) do
        exports.ox_target:addModel(modelHash, groundInteractions)
    end
end)

-- ==========================================================
-- Submenus de Recursos Avançados (Queue, History & Security)
-- ==========================================================

function OpenSpeakerQueueMenu(speakerId)
    local queue = lib.callback.await('vp_newspaper:server:getSpeakerQueue', false, speakerId) or {}
    local options = {
        {
            title = '➕ Adicionar Música à Fila',
            description = 'Enfileira uma nova faixa para tocar nesta caixa de som',
            icon = 'plus',
            onSelect = function()
                local inp = lib.inputDialog('Adicionar Música à Fila', {
                    { type = 'input', label = 'Link do YouTube ou Áudio', placeholder = 'https://youtube.com/...', required = true, icon = 'music' },
                    { type = 'input', label = 'Título da Faixa (Opcional)', placeholder = 'Nome da música', icon = 'tag' }
                })
                if inp and inp[1] then
                    TriggerServerEvent('vp_newspaper:server:addToSpeakerQueue', speakerId, inp[1], inp[2] or 'Música Enfileirada')
                end
            end
        },
        {
            title = '⏭ Pular para Próxima Faixa',
            description = 'Toca imediatamente a próxima música da fila desta caixa',
            icon = 'forward-step',
            disabled = #queue == 0,
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:skipToNextQueuedSong', speakerId)
            end
        }
    }

    if #queue > 0 then
        options[#options + 1] = {
            title = ('--- Músicas na Fila (%d) ---'):format(#queue),
            disabled = true
        }
        for idx, item in ipairs(queue) do
            options[#options + 1] = {
                title = ('#%d: %s'):format(idx, item.title),
                description = ('Adicionado por: %s'):format(item.addedBy or 'Anônimo'),
                icon = 'music',
                onSelect = function()
                    local alert = lib.alertDialog({
                        header = item.title,
                        content = 'Deseja remover esta música da fila de reprodução?',
                        centered = true,
                        cancel = true,
                        labels = { confirm = 'Remover', cancel = 'Voltar' }
                    })
                    if alert == 'confirm' then
                        TriggerServerEvent('vp_newspaper:server:removeQueueIndex', speakerId, idx)
                    end
                end
            }
        end
    else
        options[#options + 1] = {
            title = 'Fila Vazia',
            description = 'Nenhuma música agendada para tocar.',
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'weazel_speaker_queue_menu',
        title = '📜 Fila de Reprodução (Queue)',
        menu = 'weazel_speaker_control_' .. tostring(speakerId),
        options = options
    })
    lib.showContext('weazel_speaker_queue_menu')
end

function OpenSpeakerHistoryMenu(speakerId)
    local history = lib.callback.await('vp_newspaper:server:getSpeakerHistory', false) or {}
    local options = {}

    if #history > 0 then
        for _, song in ipairs(history) do
            options[#options + 1] = {
                title = song.title or 'Música Recente',
                description = ('▶ Clique para tocar: %s'):format(song.url),
                icon = 'clock-rotate-left',
                onSelect = function()
                    TriggerServerEvent('vp_newspaper:server:playSpeakerMusic', speakerId, song.url, 0)
                    lib.notify({ title = 'Histórico', description = ('Tocando: %s'):format(song.title), type = 'success' })
                end
            }
        end
    else
        options[#options + 1] = {
            title = 'Histórico Vazio',
            description = 'Você ainda não tocou músicas nesta sessão.',
            icon = 'circle-info',
            disabled = true
        }
    end

    lib.registerContext({
        id = 'weazel_speaker_history_menu',
        title = '🕒 Histórico de Músicas',
        menu = 'weazel_speaker_control_' .. tostring(speakerId),
        options = options
    })
    lib.showContext('weazel_speaker_history_menu')
end

function OpenSpeakerSecurityMenu(speakerId)
    local options = {
        {
            title = '🌐 Aberto ao Público',
            description = 'Qualquer jogador próximo pode controlar esta caixa',
            icon = 'lock-open',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:setSpeakerSecurity', speakerId, 'public')
            end
        },
        {
            title = '👤 Privado (Apenas Dono)',
            description = 'Apenas você pode controlar o som desta caixa',
            icon = 'user-lock',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:setSpeakerSecurity', speakerId, 'owner_only')
            end
        },
        {
            title = '🔑 Protegido por Senha (PIN)',
            description = 'Exige digitação de um PIN de 4 dígitos para qualquer outro jogador',
            icon = 'key',
            onSelect = function()
                local inp = lib.inputDialog('Definir PIN de Segurança', {
                    { type = 'input', label = 'Novo PIN (4 dígitos)', placeholder = '1234', password = true, required = true, min = 4, max = 8 }
                })
                if inp and inp[1] then
                    TriggerServerEvent('vp_newspaper:server:setSpeakerSecurity', speakerId, 'pin', inp[1])
                end
            end
        }
    }

    lib.registerContext({
        id = 'weazel_speaker_security_menu',
        title = '🔒 Segurança da Caixa',
        menu = 'weazel_speaker_control_' .. tostring(speakerId),
        options = options
    })
    lib.showContext('weazel_speaker_security_menu')
end

-- ==========================================================
-- Menu Interativo RAHE Speakers (YouTube, Pausa, Volume/Alcance, Rádio)
-- ==========================================================

function OpenSpeakerControlMenu(speakerId, speakerType)
    -- Validação de Permissão / PIN (Rahe Security System)
    local okAccess, accessErr = lib.callback.await('vp_newspaper:server:validateSpeakerAccess', false, speakerId, currentSpeakerUnlockedPins[speakerId])
    if not okAccess then
        local pinInput = lib.inputDialog('🔒 Caixa Protegida', {
            {
                type = 'input',
                label = 'Digite o PIN de Acesso (4 dígitos)',
                placeholder = '****',
                password = true,
                required = true,
                icon = 'lock'
            }
        })
        if not pinInput or not pinInput[1] then return end
        local retryOk, retryErr = lib.callback.await('vp_newspaper:server:validateSpeakerAccess', false, speakerId, pinInput[1])
        if not retryOk then
            lib.notify({ title = 'Acesso Negado', description = retryErr or 'PIN incorreto!', type = 'error' })
            return
        end
        currentSpeakerUnlockedPins[speakerId] = pinInput[1]
    end

    local speaker = LocalSpeakersAudio[speakerId] or {
        isPlaying = false,
        volume = 0.8,
        range = 25.0,
        isRadio = false,
        url = nil,
        title = 'Nenhuma'
    }

    local currentTitle = speaker.title or 'Nenhuma'
    if speaker.isRadio then
        currentTitle = (currentStation and currentStation.currentTrack) and currentStation.currentTrack.title or 'Weazel Radio 98.5 FM'
    end

    local statusText = speaker.isPlaying and ('▶ Tocando: %s'):format(currentTitle) or '⏸ Parada / Ociosa'

    local options = {
        {
            title = 'Status: ' .. statusText,
            description = ('Volume: %d%% | Alcance: %.0fm'):format(math.floor((speaker.volume or 0.8) * 100), speaker.range or 25),
            icon = speaker.isPlaying and 'music' or 'circle-pause',
            disabled = true
        },
        {
            title = 'Tocar Música (YouTube / Link)',
            description = 'Suporta links de vídeos e playlists do YouTube ou streams web',
            icon = 'play',
            onSelect = function()
                local input = lib.inputDialog('Tocar Música na Caixa de Som', {
                    {
                        type = 'input',
                        label = 'Link do YouTube ou Áudio',
                        description = 'Cole a URL do vídeo ou playlist do YouTube (youtube.com ou youtu.be)',
                        placeholder = 'https://www.youtube.com/watch?v=...',
                        required = true,
                        icon = 'music'
                    },
                    {
                        type = 'number',
                        label = 'Pular para o Segundo (Timestamp)',
                        description = 'Tempo inicial de reprodução em segundos (0 = do início)',
                        default = 0,
                        min = 0,
                        icon = 'clock'
                    }
                })

                if not input or not input[1] then return end
                TriggerServerEvent('vp_newspaper:server:playSpeakerMusic', speakerId, input[1], input[2] or 0)
            end
        },
        {
            title = speaker.isPlaying and 'Pausar Música' or 'Retomar Reprodução',
            description = speaker.isPlaying and 'Pausa temporariamente o som desta caixa' or 'Retoma o som da caixa',
            icon = speaker.isPlaying and 'pause' or 'play',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:pauseSpeakerMusic', speakerId)
            end
        },
        {
            title = 'Parar Reprodução',
            description = 'Para totalmente a música e deixa a caixa ociosa',
            icon = 'stop',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:stopSpeakerMusic', speakerId)
            end
        },
        {
            title = 'Ajustar Volume e Alcance',
            description = 'Regula a potência do som e a distância máxima audível em metros',
            icon = 'sliders',
            onSelect = function()
                local input = lib.inputDialog('Volume & Alcance do Som', {
                    {
                        type = 'number',
                        label = 'Volume (10% a 100%)',
                        default = math.floor((speaker.volume or 0.8) * 100),
                        min = 10,
                        max = 100,
                        step = 5,
                        icon = 'volume-high'
                    },
                    {
                        type = 'number',
                        label = 'Alcance do Som (1m a 45m)',
                        default = math.floor(speaker.range or 25),
                        min = 1,
                        max = 45,
                        step = 1,
                        icon = 'radio'
                    }
                })

                if not input or not input[1] or not input[2] then return end
                TriggerServerEvent('vp_newspaper:server:setSpeakerVolumeRange', speakerId, input[1] / 100, input[2])
            end
        },
        {
            title = 'Sintonizar Weazel Radio 98.5 FM',
            description = 'Conecta a caixa à transmissão ao vivo da rádio Weazel',
            icon = 'tower-broadcast',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:tuneSpeakerToRadio', speakerId)
            end
        }
    }

    -- ---- Seção: Renomear & Equalizador da Caixa ----
    local speaker = LocalSpeakersAudio[speakerId]
    options[#options + 1] = {
        title = '🏷️ Renomear Caixa de Som',
        description = ('Nome atual: %s'):format((speaker and speaker.name) or 'Caixa de Som'),
        icon = 'tag',
        onSelect = function()
            local inp = lib.inputDialog('Renomear Caixa', {
                { type = 'input', label = 'Novo Nome da Caixa', default = (speaker and speaker.name) or 'Caixa de Som', required = true, max = 50 }
            })
            if inp and inp[1] then
                TriggerServerEvent('vp_newspaper:server:renameSpeaker', speakerId, inp[1])
            end
        end
    }

    options[#options + 1] = {
        title = '🎛️ Equalizador / Filtro Acústico',
        description = ('Preset atual: %s'):format(string.upper((speaker and speaker.eqPreset) or 'flat')),
        icon = 'sliders',
        onSelect = function()
            local eqPresets = {
                { id = 'flat', label = 'Flat (Padrão)', desc = 'Áudio original limpo sem alterações de frequência' },
                { id = 'bass', label = 'Bass Boost (Graves Fortes)', desc = 'Realce potente de sub-graves para pancadão e festas' },
                { id = 'vocal', label = 'Vocal & Notícias', desc = 'Ênfase em frequências médias para clareza da voz' },
                { id = 'club', label = 'Club & Nightclub', desc = 'Equilíbrio de graves e agudos reforçados' },
                { id = 'outdoor', label = 'Outdoor (Ar Livre)', desc = 'Compensação acústica para áreas abertas' }
            }
            local eqOptions = {}
            for _, p in ipairs(eqPresets) do
                eqOptions[#eqOptions + 1] = {
                    title = p.label,
                    description = p.desc,
                    icon = 'wave-square',
                    onSelect = function()
                        TriggerServerEvent('vp_newspaper:server:setSpeakerEQ', speakerId, p.id)
                    end
                }
            end
            lib.registerContext({
                id = 'weazel_speaker_eq_' .. tostring(speakerId),
                title = 'Equalizador da Caixa',
                menu = 'weazel_speaker_control_' .. tostring(speakerId),
                options = eqOptions
            })
            lib.showContext('weazel_speaker_eq_' .. tostring(speakerId))
        end
    }

    -- ---- Seção: Grupos de Som (Rahe Speaker Groups) ----
    local isInGroup = speaker and speaker.groupId ~= nil
    local currentGroup = isInGroup and SpeakerGroups[speaker.groupId] or nil

    options[#options + 1] = {
        title = '🎶 Grupos de Som (Sincronizar Caixas)',
        description = isInGroup
            and ('Conectada ao Grupo: "%s"'):format(currentGroup and currentGroup.name or ('#%d'):format(speaker.groupId))
            or 'Conecta múltiplas caixas para tocar em sincronia',
        icon = 'people-group',
        onSelect = function()
            local groupOptions = {}

            if not isInGroup then
                groupOptions[#groupOptions + 1] = {
                    title = '🔗 Conectar a um Grupo (Código de Conexão)',
                    description = 'Conecta esta caixa a um grupo já criado',
                    icon = 'link',
                    onSelect = function()
                        local inp = lib.inputDialog('Conectar Caixa ao Grupo', {
                            { type = 'input', label = 'Código de Conexão do Grupo (Connect Code)', placeholder = 'Ex: PRAIA1', required = true }
                        })
                        if inp and inp[1] then
                            TriggerServerEvent('vp_newspaper:server:addToGroup', speakerId, inp[1])
                        end
                    end
                }
                groupOptions[#groupOptions + 1] = {
                    title = '✨ Criar Novo Grupo de Som',
                    description = 'Cria um novo grupo de caixas com código de acesso e código de conexão',
                    icon = 'plus-circle',
                    onSelect = function()
                        local inp = lib.inputDialog('Criar Grupo de Som', {
                            { type = 'input', label = 'Nome do Grupo', placeholder = 'Festa na Praia', required = true },
                            { type = 'input', label = 'Código de Conexão (Connect Code)', description = 'Código que outras caixas usam para conectar', required = true },
                            { type = 'input', label = 'Código de Acesso (Access Code)', description = 'Código para você controlar o grupo', required = true }
                        })
                        if inp and inp[1] and inp[2] and inp[3] then
                            TriggerServerEvent('vp_newspaper:server:createSpeakerGroup', inp[1], inp[2], inp[3])
                        end
                    end
                }
                groupOptions[#groupOptions + 1] = {
                    title = '🔓 Acessar Painel de Grupo Existente',
                    description = 'Acessa o painel de um grupo pelo seu Código de Acesso',
                    icon = 'key',
                    onSelect = function()
                        local inp = lib.inputDialog('Acessar Painel do Grupo', {
                            { type = 'input', label = 'Código de Acesso do Grupo', required = true }
                        })
                        if inp and inp[1] then
                            TriggerServerEvent('vp_newspaper:server:accessSpeakerGroup', inp[1])
                        end
                    end
                }
            else
                groupOptions[#groupOptions + 1] = {
                    title = ('📡 Conectada ao Grupo: %s'):format(currentGroup and currentGroup.name or 'Grupo de Som'),
                    description = currentGroup and ('Código de Conexão: %s'):format(currentGroup.connectCode) or '',
                    icon = 'circle-info',
                    disabled = true
                }
                groupOptions[#groupOptions + 1] = {
                    title = '🔌 Desconectar Desta Caixa do Grupo',
                    description = 'Remove esta caixa do grupo e volta ao modo autônomo',
                    icon = 'circle-xmark',
                    onSelect = function()
                        TriggerServerEvent('vp_newspaper:server:removeFromGroup', speakerId)
                    end
                }
                if currentGroup then
                    groupOptions[#groupOptions + 1] = {
                        title = '🎛️ Abrir Painel de Controle do Grupo',
                        description = 'Controla músicas e fila de todo o grupo',
                        icon = 'music',
                        onSelect = function()
                            OpenSpeakerGroupMenu(currentGroup)
                        end
                    }
                end
            end

            lib.registerContext({
                id = 'weazel_speaker_group_menu',
                title = '🎶 Grupos de Som',
                menu = 'weazel_speaker_control_' .. tostring(speakerId),
                options = groupOptions
            })
            lib.showContext('weazel_speaker_group_menu')
        end
    }

    -- ---- Recursos Avançados RAHE (Queue, History & Security) ----
    options[#options + 1] = {
        title = '📜 Fila de Reprodução (Queue)',
        description = 'Enfileira e gerencia as próximas músicas desta caixa',
        icon = 'list-ol',
        onSelect = function()
            OpenSpeakerQueueMenu(speakerId)
        end
    }

    options[#options + 1] = {
        title = '🕒 Histórico de Músicas Tocadas',
        description = 'Lista as últimas músicas tocadas com reprodução rápida em 1 clique',
        icon = 'clock-rotate-left',
        onSelect = function()
            OpenSpeakerHistoryMenu(speakerId)
        end
    }

    options[#options + 1] = {
        title = '🔒 Segurança & Permissões',
        description = 'Defina acesso público, apenas dono ou senha PIN de 4 dígitos',
        icon = 'shield-halved',
        onSelect = function()
            OpenSpeakerSecurityMenu(speakerId)
        end
    }

    if speakerType == 'ground' then
        options[#options + 1] = {
            title = '🏛 Fixar como Caixa Permanente (Admin)',
            description = 'Salva esta caixa no banco de dados para persistir para sempre no mapa',
            icon = 'building-columns',
            onSelect = function()
                local netId = tonumber(speakerId:sub(8))
                if netId then
                    local inp = lib.inputDialog('Tornar Caixa Permanente', {
                        { type = 'input', label = 'Nome do Ponto / Praça', placeholder = 'Ex: Som da Praça Central', required = true }
                    })
                    if inp and inp[1] then
                        TriggerServerEvent('vp_newspaper:server:makeSpeakerPermanent', netId, inp[1])
                    end
                end
            end
        }
    end

    if speakerType == 'ground' then
        options[#options + 1] = {
            title = 'Pegar no Ombro',
            description = 'Coloca esta caixa tocando no seu ombro',
            icon = 'person-walking',
            onSelect = function()
                local netId = tonumber(speakerId:sub(8))
                local entity = NetworkDoesNetworkIdExist(netId) and NetworkGetEntityFromNetworkId(netId) or nil
                CarryGroundSpeakerToShoulder(netId, entity)
            end
        }
    end

    if speakerType == 'carried' then
        options[#options + 1] = {
            title = 'Colocar no Chão',
            description = 'Posiciona a caixa no chão mantendo o som ativo',
            icon = 'compact-disc',
            onSelect = function()
                StopCarryingBoombox()
                PlaceGroundRadio(currentSpeakerType)
            end
        }
        options[#options + 1] = {
            title = 'Guardar na Mochila',
            description = 'Guarda a caixa de som de volta no inventário',
            icon = 'box-archive',
            onSelect = function()
                StopCarryingBoombox()
                TriggerServerEvent('vp_newspaper:server:clearSpeakerAudio', speakerId)
                lib.notify({ title = 'Caixa de Som', description = 'Caixa guardada.', type = 'inform' })
            end
        }
    end

    lib.registerContext({
        id = 'weazel_speaker_control_' .. tostring(speakerId),
        title = 'Controle da Caixa de Som',
        options = options
    })
    lib.showContext('weazel_speaker_control_' .. tostring(speakerId))
end

-- ==========================================================
-- Handlers de Menus de Grupo Dedicados & Admin (Client-side)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:openSpeakerGroupMenu', function(group)
    OpenSpeakerGroupMenu(group)
end)

function OpenSpeakerGroupMenu(group)
    local options = {}

    if group then
        options[#options + 1] = {
            title = ('📡 Grupo Ativo: %s'):format(group.name),
            description = ('Connect Code: %s | Access Code: %s'):format(group.connectCode, group.accessCode),
            icon = 'circle-info',
            disabled = true
        }

        options[#options + 1] = {
            title = group.isPlaying and '⏸ Pausar / Retomar Grupo' or '▶ Tocar Música no Grupo',
            description = group.isPlaying and 'Alterna reprodução de todas as caixas' or 'Inicia música simultânea em todas as caixas',
            icon = group.isPlaying and 'pause' or 'play',
            onSelect = function()
                if group.isPlaying then
                    TriggerServerEvent('vp_newspaper:server:pauseResumeGroup', group.id)
                else
                    local inp = lib.inputDialog('Tocar Música no Grupo ' .. group.name, {
                        { type = 'input', label = 'Link do YouTube ou Áudio', placeholder = 'https://youtube.com/...', required = true, icon = 'music' },
                        { type = 'number', label = 'Pular Segundos (Timestamp)', default = 0, min = 0, icon = 'clock' }
                    })
                    if inp and inp[1] then
                        TriggerServerEvent('vp_newspaper:server:playGroupMusic', group.id, inp[1], inp[2] or 0)
                    end
                end
            end
        }

        options[#options + 1] = {
            title = '➕ Adicionar à Fila do Grupo',
            description = 'Enfileira uma faixa no grupo',
            icon = 'plus',
            onSelect = function()
                local inp = lib.inputDialog('Fila do Grupo', {
                    { type = 'input', label = 'Link do YouTube ou Áudio', required = true, icon = 'music' },
                    { type = 'input', label = 'Título da Faixa', placeholder = 'Nome da música', icon = 'tag' }
                })
                if inp and inp[1] then
                    TriggerServerEvent('vp_newspaper:server:addToGroupQueue', group.id, inp[1], inp[2] or 'Música no Grupo')
                end
            end
        }

        options[#options + 1] = {
            title = '⏭ Pular Música do Grupo',
            description = 'Avança para a próxima música da fila deste grupo',
            icon = 'forward-step',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:nextGroupSong', group.id)
            end
        }
    end

    options[#options + 1] = {
        title = '✨ Criar Novo Grupo de Som',
        description = 'Cria um novo grupo de caixas com código de acesso e código de conexão',
        icon = 'plus-circle',
        onSelect = function()
            local inp = lib.inputDialog('Criar Grupo de Caixas de Som', {
                { type = 'input', label = 'Nome do Grupo', placeholder = 'Festa na Praia', required = true },
                { type = 'input', label = 'Código de Conexão (Ex: PRAIA1)', description = 'Outras caixas usam este código para conectar', required = true },
                { type = 'input', label = 'Código de Acesso (Ex: SENHA123)', description = 'Código para você gerenciar o grupo', required = true }
            })
            if inp and inp[1] and inp[2] and inp[3] then
                TriggerServerEvent('vp_newspaper:server:createSpeakerGroup', inp[1], inp[2], inp[3])
            end
        end
    }

    options[#options + 1] = {
        title = '🔓 Acessar Outro Grupo (Código de Acesso)',
        description = 'Acessa o painel de controle de um grupo criado anteriormente',
        icon = 'key',
        onSelect = function()
            local inp = lib.inputDialog('Acessar Grupo de Som', {
                { type = 'input', label = 'Código de Acesso', placeholder = 'Digite o código de acesso', required = true }
            })
            if inp and inp[1] then
                TriggerServerEvent('vp_newspaper:server:accessSpeakerGroup', inp[1])
            end
        end
    }

    lib.registerContext({
        id = 'weazel_speaker_group_dashboard',
        title = '🎶 Painel de Grupos de Som',
        options = options
    })
    lib.showContext('weazel_speaker_group_dashboard')
end

RegisterCommand('caixasomgrupo', function()
    OpenSpeakerGroupMenu()
end, false)

-- ==========================================================
-- Painel de Administrador (/speakersadmin & /streamermode)
-- ==========================================================

function OpenSpeakerAdminMenu()
    local ok, list = lib.callback.await('vp_newspaper:server:getAdminSpeakersList', false)
    if not ok or not list then
        lib.notify({ title = 'Admin', description = list or 'Você não possui permissão de administrador.', type = 'error' })
        return
    end

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local options = {
        {
            title = '🛑 EMERGÊNCIA: Silenciar Todas as Caixas',
            description = 'Interrompe imediatamente todos os sons de caixas do servidor',
            icon = 'triangle-exclamation',
            iconColor = '#FF3333',
            onSelect = function()
                local confirm = lib.alertDialog({
                    header = 'Silenciar Todos os Sons',
                    content = 'Tem certeza que deseja interromper todos os sons e caixas do servidor agora?',
                    centered = true,
                    cancel = true
                })
                if confirm == 'confirm' then
                    TriggerServerEvent('vp_newspaper:server:adminKillAllSpeakers')
                end
            end
        },
        {
            title = ('--- Caixas Ativas no Servidor (%d) ---'):format(#list),
            disabled = true
        }
    }

    for _, spk in ipairs(list) do
        local dist = #(pCoords - spk.coords)
        local status = spk.isPlaying and '▶ TOCANDO' or '⏸ PARADA'
        options[#options + 1] = {
            title = ('[%s] %s'):format(string.upper(spk.type), spk.name),
            description = ('Status: %s | Distância: %.1fm | Vol: %.0f%%'):format(status, dist, (spk.volume or 0.8) * 100),
            icon = 'music',
            arrow = true,
            onSelect = function()
                local subOptions = {
                    {
                        title = '📍 Teleportar até a Caixa',
                        description = ('Coordenadas: %.1f, %.1f, %.1f'):format(spk.coords.x, spk.coords.y, spk.coords.z),
                        icon = 'location-dot',
                        onSelect = function()
                            SetEntityCoords(PlayerPedId(), spk.coords.x, spk.coords.y, spk.coords.z + 0.5)
                            lib.notify({ title = 'Admin', description = 'Teleportado para a caixa.', type = 'success' })
                        end
                    },
                    {
                        title = '🗑️ Deletar / Remover Caixa',
                        description = 'Remove o prop e exclui esta caixa permanentemente',
                        icon = 'trash',
                        onSelect = function()
                            TriggerServerEvent('vp_newspaper:server:adminDeleteSpeaker', spk.speakerId)
                        end
                    }
                }
                lib.registerContext({
                    id = 'weazel_admin_speaker_details',
                    title = spk.name,
                    menu = 'weazel_speaker_admin_menu',
                    options = subOptions
                })
                lib.showContext('weazel_admin_speaker_details')
            end
        }
    end

    lib.registerContext({
        id = 'weazel_speaker_admin_menu',
        title = '🛠️ Painel Admin de Caixas de Som',
        options = options
    })
    lib.showContext('weazel_speaker_admin_menu')
end

RegisterCommand('speakersadmin', function()
    OpenSpeakerAdminMenu()
end, false)

RegisterCommand('streamermode', function()
    OpenSafetyPreferenceMenu()
end, false)

-- ==========================================================
-- Menu Unificado de Caixa de Som Portátil (Item Usável)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:openPortableRadioMenu', function(speakerType)
    -- Normaliza o tipo recebido do servidor (legado radio_portable = 'retro')
    speakerType = speakerType or currentSpeakerType or 'retro'
    if not Config.General.SpeakerTypes or not Config.General.SpeakerTypes[speakerType] then
        speakerType = 'retro'
    end
    currentSpeakerType = speakerType

    local typeCfg  = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local typeLabel = typeCfg and typeCfg.label or 'Caixa de Som Portátil'
    local typeIcon  = typeCfg and typeCfg.icon or '🔊'

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local nearVeh = GetClosestVehicle(pCoords.x, pCoords.y, pCoords.z, 3.5, 0, 71)
    local myServerId = GetPlayerServerId(PlayerId())
    local carriedSpeakerKey = 'carried_' .. tostring(myServerId)

    if isCarryingBoombox then
        OpenSpeakerControlMenu(carriedSpeakerKey, 'carried')
        return
    end

    local maxRange  = typeCfg and typeCfg.maxRange  or 35.0
    local maxVolStr = typeCfg and ('Volume máx: %d%% | Alcance máx: %.0fm'):format(math.floor((typeCfg.maxVolume or 1.0) * 100), maxRange) or ''

    local options = {
        {
            title = typeIcon .. ' ' .. typeLabel,
            description = maxVolStr,
            icon = 'circle-info',
            disabled = true
        },
        {
            title = 'Carregar no ' .. (typeCfg and typeCfg.carryType == 'box_carry' and 'Colo (Duas Mãos)' or 'Ombro'),
            description = 'Carrega a caixa com áudio 3D sincronizado para todos',
            icon = 'person-walking',
            onSelect = function()
                StartCarryingBoombox(speakerType)
            end
        },
        {
            title = 'Colocar no Chão',
            description = 'Posiciona a caixa de som no chão com áudio 3D espacial',
            icon = 'compact-disc',
            onSelect = function()
                PlaceGroundRadio(speakerType)
            end
        }
    }

    if nearVeh and nearVeh ~= 0 then
        options[#options + 1] = {
            title = 'Instalar no Veículo Próximo',
            description = 'Acopla o som no porta-malas, teto ou caçamba do veículo',
            icon = 'car',
            onSelect = function()
                OpenInstallSpeakerMenu(nearVeh)
            end
        }
    end

    lib.registerContext({
        id = 'weazel_portable_radio_initial',
        title = typeIcon .. ' ' .. typeLabel,
        options = options
    })
    lib.showContext('weazel_portable_radio_initial')
end)

function StartPlacingSpeakerPreview(speakerType)
    if isPlacingSpeakerPreview then return end
    speakerType = speakerType or currentSpeakerType or 'retro'
    local typeData = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local modelHash = (typeData and typeData.model) or (Config.General.Radio and Config.General.Radio.portableProp) or joaat('prop_boombox_01')

    lib.requestModel(modelHash)

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local pHeading = GetEntityHeading(ped)
    local curHeading = pHeading

    local previewObj = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z, false, false, false)
    SetEntityCollision(previewObj, false, false)
    SetEntityAlpha(previewObj, 190, false)

    isPlacingSpeakerPreview = true

    lib.showTextUI('[Q / E] Girar | [ENTER] Posicionar | [X] Cancelar', {
        position = 'left-center',
        icon = 'arrows-spin'
    })

    CreateThread(function()
        while isPlacingSpeakerPreview do
            Wait(0)
            local p = PlayerPedId()
            local coords = GetEntityCoords(p)
            local fwd = GetEntityForwardVector(p)
            local placePos = coords + (fwd * 1.2)

            SetEntityCoords(previewObj, placePos.x, placePos.y, placePos.z - 0.95, false, false, false, false)
            PlaceObjectOnGroundProperly(previewObj)
            SetEntityHeading(previewObj, curHeading)

            -- [Q] Girar para a esquerda
            if IsControlPressed(0, 44) then
                curHeading = (curHeading + 2.0) % 360.0
            end

            -- [E] Girar para a direita
            if IsControlPressed(0, 38) then
                curHeading = (curHeading - 2.0) % 360.0
            end

            -- [ENTER] Confirmar
            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) then
                isPlacingSpeakerPreview = false
                local finalCoords = GetEntityCoords(previewObj)
                DeleteEntity(previewObj)
                lib.hideTextUI()
                PlaceGroundRadio(speakerType, finalCoords, curHeading)
                break
            end

            -- [X / BACKSPACE] Cancelar
            if IsControlJustPressed(0, 73) or IsControlJustPressed(0, 177) then
                isPlacingSpeakerPreview = false
                DeleteEntity(previewObj)
                lib.hideTextUI()
                lib.notify({ title = 'Caixa de Som', description = 'Posicionamento cancelado.', type = 'inform' })
                break
            end
        end
    end)
end

function PlaceGroundRadio(speakerType, customCoords, customHeading)
    speakerType = speakerType or currentSpeakerType or 'retro'

    -- Se chamado sem coordenadas, inicia o modo de preview interativo (Rahe Placement Mode)
    if not customCoords then
        StartPlacingSpeakerPreview(speakerType)
        return
    end

    local typeData = Config.General.SpeakerTypes and Config.General.SpeakerTypes[speakerType]
    local modelHash = (typeData and typeData.model) or (Config.General.Radio and Config.General.Radio.portableProp) or joaat('prop_boombox_01')

    local ped = PlayerPedId()
    lib.requestModel(modelHash)
    lib.requestAnimDict('anim@mp_snowball')

    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 2.0, -8.0, 1500, 49, 0, false, false, false)
    Wait(1200)

    local obj = CreateObject(modelHash, customCoords.x, customCoords.y, customCoords.z, true, true, false)
    PlaceObjectOnGroundProperly(obj)
    if customHeading then
        SetEntityHeading(obj, customHeading)
    end
    FreezeEntityPosition(obj, true)

    local netId = NetworkGetNetworkIdFromEntity(obj)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)

    local myServerId = GetPlayerServerId(PlayerId())
    local carriedKey = 'carried_' .. tostring(myServerId)
    local hadCarriedAudio = LocalSpeakersAudio[carriedKey] ~= nil

    TriggerServerEvent('vp_newspaper:server:registerGroundSpeaker', customCoords, netId, hadCarriedAudio, speakerType)

    UpdateRadioPlayback()
    local label = typeData and typeData.label or 'Caixa de Som'
    lib.notify({ title = label, description = 'Colocada no chão! Áudio 3D sincronizado.', type = 'success' })
end

function CarryGroundSpeakerToShoulder(netId, entity)
    local ped = PlayerPedId()
    lib.requestAnimDict('anim@mp_snowball')
    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 2.0, -8.0, 1000, 49, 0, false, false, false)
    Wait(700)

    local ok, transferredAudio, returnedSpeakerType = lib.callback.await('vp_newspaper:server:carryGroundSpeaker', false, netId)
    if ok then
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        local myServerId = GetPlayerServerId(PlayerId())
        local carriedKey = 'carried_' .. tostring(myServerId)
        local groundKey = 'ground_' .. tostring(netId)
        LocalSpeakersAudio[groundKey] = nil
        if transferredAudio then
            LocalSpeakersAudio[carriedKey] = transferredAudio
        end
        StartCarryingBoombox(returnedSpeakerType or currentSpeakerType)
        lib.notify({ title = 'Caixa de Som', description = 'Caixa colocada no ombro com sucesso!', type = 'success' })
        UpdateRadioPlayback()
    else
        lib.notify({ title = 'Caixa de Som', description = transferredAudio or 'Falha ao pegar no ombro.', type = 'error' })
    end
end

function PickupGroundSpeaker(netId, entity)
    local ped = PlayerPedId()
    lib.requestAnimDict('anim@mp_snowball')
    TaskPlayAnim(ped, 'anim@mp_snowball', 'pickup_snowball', 2.0, -8.0, 1500, 49, 0, false, false, false)
    Wait(1000)

    local ok, err = lib.callback.await('vp_newspaper:server:pickupGroundSpeaker', false, netId)
    if ok then
        if entity and DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
        LocalSpeakersAudio['ground_' .. tostring(netId)] = nil
        lib.notify({ title = 'Caixa de Som', description = 'Caixa de som recolhida com sucesso!', type = 'success' })
        UpdateRadioPlayback()
    else
        lib.notify({ title = 'Caixa de Som', description = err or 'Não foi possível recolher.', type = 'error' })
    end
end

RegisterCommand('pegarcaixa', function()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local closestNetId = nil
    local closestEntity = nil
    local closestDist = 3.5

    for netId, speaker in pairs(ActiveGroundSpeakers) do
        local dist = #(pCoords - speaker.coords)
        if dist < closestDist then
            closestDist = dist
            closestNetId = netId
            if NetworkDoesNetworkIdExist(netId) then
                closestEntity = NetworkGetEntityFromNetworkId(netId)
            end
        end
    end

    if closestNetId then
        PickupGroundSpeaker(closestNetId, closestEntity)
    else
        lib.notify({ title = 'Caixa de Som', description = 'Nenhuma caixa de som próxima para recolher!', type = 'error' })
    end
end, false)

RegisterCommand('recolhersom', function()
    ExecuteCommand('pegarcaixa')
end, false)

RegisterNetEvent('vp_newspaper:client:placePortableRadio', function()
    PlaceGroundRadio()
end)

RegisterNetEvent('vp_newspaper:client:toggleHeadphones', function()
    isHeadphonesOn = not isHeadphonesOn
    UpdateRadioPlayback()
    lib.notify({
        title = 'Fones Weazel',
        description = isHeadphonesOn and 'Fones conectados na Weazel Radio!' or 'Fones desconectados.',
        type = 'info'
    })
end)

-- ==========================================================
-- Menus de Sintonizador, Equalizador & Modo Streamer
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:openRadioMenu', function()
    local ped = PlayerPedId()
    local inVeh = IsPedInAnyVehicle(ped, false)

    local trackTitle = (currentStation and currentStation.currentTrack) and currentStation.currentTrack.title or 'Sem transmissão no momento'
    local statusText = (currentStation and currentStation.isPlaying) and '🔴 AO VIVO' or '⚪ FORA DO AR'

    local options = {
        {
            title = 'Estação: Weazel News 98.5 FM',
            description = ('Status: %s\nTocando: %s'):format(statusText, trackTitle),
            icon = 'radio',
            disabled = true
        }
    }

    if inVeh then
        options[#options + 1] = {
            title = isVehicleRadioOn and 'Desligar Rádio do Carro' or 'Sintonizar no Painel do Carro',
            description = 'Alternar sintonizador do veículo na frequência 98.5 FM',
            icon = 'car',
            onSelect = function()
                isVehicleRadioOn = not isVehicleRadioOn
                UpdateRadioPlayback()
                lib.notify({ title = 'Rádio', description = isVehicleRadioOn and 'Rádio do carro sintonizado!' or 'Rádio do carro desligado.', type = 'info' })
            end
        }
    end

    options[#options + 1] = {
        title = isHeadphonesOn and 'Desconectar Fones de Ouvido' or 'Colocar Fones de Ouvido (Signalbuds)',
        description = 'Escutar a Weazel Radio privativamente no ouvido',
        icon = 'headphones',
        onSelect = function()
            isHeadphonesOn = not isHeadphonesOn
            UpdateRadioPlayback()
            lib.notify({ title = 'Fones', description = isHeadphonesOn and 'Fones conectados!' or 'Fones desconectados.', type = 'info' })
        end
    }

    options[#options + 1] = {
        title = 'Ajustar Volume',
        description = ('Volume Atual: %d%%'):format(math.floor(userVolume * 100)),
        icon = 'volume-high',
        onSelect = function()
            local input = lib.inputDialog('Volume da Weazel Radio', {
                { type = 'slider', label = 'Volume (0 a 100)', min = 0, max = 100, default = math.floor(userVolume * 100) }
            })
            if input and input[1] ~= nil then
                userVolume = input[1] / 100.0
                UpdateRadioPlayback()
            end
        end
    }

    options[#options + 1] = {
        title = 'Equalizador de Áudio (Biquad EQ)',
        description = 'Ajustar curvas de frequência acústica e presets analógicos',
        icon = 'sliders',
        onSelect = function()
            OpenEqualizerMenu()
        end
    }

    options[#options + 1] = {
        title = 'Preferência de Transmissão (Modo Streamer)',
        description = 'Configurar proteção contra DMCA e modo de áudio',
        icon = 'shield-halved',
        onSelect = function()
            OpenSafetyPreferenceMenu()
        end
    }

    lib.registerContext({
        id = 'weazel_radio_tuner_menu',
        title = 'Sintonizador Weazel Radio',
        options = options
    })
    lib.showContext('weazel_radio_tuner_menu')
end)

function OpenEqualizerMenu()
    local presets = {
        { id = 'broadcast', label = 'Broadcast FM (Padrão)', desc = 'Assinatura acústica clássica de rádio de Los Santos' },
        { id = 'bass', label = 'Bass Boost (Graves Pesados)', desc = 'Reforço de sub-graves (80Hz) para som automotivo' },
        { id = 'vocal', label = 'Vocal & Notícias', desc = 'Ênfase em frequências médias (1kHz-4kHz) para clareza na fala' },
        { id = 'club', label = 'Club & Balada', desc = 'Graves profundos e agudos cristalinos acentuados' },
        { id = 'outdoor', label = 'Outdoor / PA', desc = 'Compensação de ar livre para caixas de som abertas' },
        { id = 'flat', label = 'Flat (Neutro)', desc = 'Áudio estéreo original sem filtros de equalização' },
    }

    local options = {}
    for _, p in ipairs(presets) do
        options[#options + 1] = {
            title = p.label,
            description = p.desc,
            icon = 'wave-square',
            onSelect = function()
                SendNUIMessage({
                    action = 'setEQ',
                    preset = p.id
                })
                SetResourceKvp('vp_newspaper_eq_preset', p.id)
                lib.notify({
                    title = 'Equalizador Weazel Audio',
                    description = ('Preset "%s" aplicado com sucesso!'):format(p.label),
                    type = 'success'
                })
            end
        }
    end

    lib.registerContext({
        id = 'weazel_radio_eq_menu',
        title = 'Equalizador Paramétrico Weazel',
        menu = 'weazel_radio_tuner_menu',
        options = options
    })
    lib.showContext('weazel_radio_eq_menu')
end

function OpenSafetyPreferenceMenu()
    local options = {
        {
            title = 'Tudo Liberado (Padrão)',
            description = 'Ouve todas as músicas, transmissões de rádio e caixas de som normalmente',
            icon = 'volume-high',
            onSelect = function()
                SetSafetyPreference('all')
            end
        },
        {
            title = 'Modo Streamer (DMCA Safe)',
            description = 'Muta músicas de terceiros, preservando avisos de plantão urgente e áudio de voz',
            icon = 'shield-halved',
            onSelect = function()
                SetSafetyPreference('streamer')
            end
        },
        {
            title = 'Mudo Completo',
            description = 'Silencia todo o áudio de transmissões e caixas de som',
            icon = 'volume-xmark',
            onSelect = function()
                SetSafetyPreference('muted')
            end
        }
    }

    lib.registerContext({
        id = 'weazel_safety_pref_menu',
        title = 'Modo Streamer & Segurança',
        menu = 'weazel_radio_tuner_menu',
        options = options
    })
    lib.showContext('weazel_safety_pref_menu')
end

function SetSafetyPreference(mode)
    SetResourceKvp('vp_newspaper_safety_mode', mode)
    SendNUIMessage({
        action = 'setSafetyPreference',
        mode = mode
    })

    local labels = {
        all = 'Áudio Completo Ativo',
        streamer = 'Modo Streamer (DMCA Safe) Ativado',
        muted = 'Áudio de Transmissão Mutado'
    }

    lib.notify({
        title = 'Preferência de Áudio',
        description = labels[mode] or 'Preferência atualizada.',
        type = 'info'
    })
end

RegisterCommand('safetypreference', function()
    OpenSafetyPreferenceMenu()
end, false)

RegisterCommand('modostreamer', function()
    OpenSafetyPreferenceMenu()
end, false)

-- Restaura configurações salvas ao iniciar
CreateThread(function()
    Wait(2000)
    local savedMode = GetResourceKvpString('vp_newspaper_safety_mode')
    if savedMode then
        SendNUIMessage({ action = 'setSafetyPreference', mode = savedMode })
    end

    local savedEq = GetResourceKvpString('vp_newspaper_eq_preset')
    if savedEq then
        SendNUIMessage({ action = 'setEQ', preset = savedEq })
    end
end)

-- ==========================================================
-- Mesa de Controle do DJ / Redação (/weazeldj)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:openDjMenu', function()
    local trackTitle = (currentStation and currentStation.currentTrack) and currentStation.currentTrack.title or 'Nenhuma'
    local queueCount = currentStation and currentStation.queueCount or 0

    local options = {
        {
            title = 'No Ar: ' .. trackTitle,
            description = ('Fila: %d faixas agendadas'):format(queueCount),
            icon = 'compact-disc',
            disabled = true
        },
        {
            title = 'Equalizador de Transmissão (Biquad EQ)',
            description = 'Ajustar perfil acústico da rádio no ar',
            icon = 'sliders',
            onSelect = function()
                OpenEqualizerMenu()
            end
        },
        {
            title = 'Adicionar Música ou Playlist',
            description = 'Inserir vídeo individual, playlist do YouTube ou link de rádio',
            icon = 'plus',
            onSelect = function()
                local input = lib.inputDialog('Adicionar à Programação da Rádio', {
                    { type = 'input', label = 'Nome / Título (Música ou Playlist)', required = true },
                    { type = 'input', label = 'Link do YouTube (Vídeo / Playlist) ou Áudio', placeholder = 'https://www.youtube.com/watch?v=... ou playlist?list=...', required = true }
                })
                if input and input[1] and input[2] then
                    TriggerServerEvent('vp_newspaper:server:addRadioTrack', input[2], input[1])
                end
            end
        },
        {
            title = 'Pular Faixa Atual (Next Track)',
            description = 'Avança para a próxima música agendada na fila',
            icon = 'forward-step',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:skipRadioTrack')
            end
        },
        {
            title = (currentStation and currentStation.isPlaying) and 'Pausar Transmissão' or 'Retomar Transmissão',
            description = 'Pausa ou retoma a execução da rádio',
            icon = (currentStation and currentStation.isPlaying) and 'pause' or 'play',
            onSelect = function()
                TriggerServerEvent('vp_newspaper:server:toggleRadioPause')
            end
        }
    }

    lib.registerContext({
        id = 'weazel_dj_console_menu',
        title = 'Mesa de Som Weazel Radio',
        options = options
    })
    lib.showContext('weazel_dj_console_menu')
end)

-- Limpeza ao parar o recurso
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SendNUIMessage({ action = 'stopRadio' })

    StopCarryingBoombox()

    if isPlacingSpeakerPreview then
        isPlacingSpeakerPreview = false
        lib.hideTextUI()
    end

    if ActiveGroundSpeakers then
        for netId, _ in pairs(ActiveGroundSpeakers) do
            if NetworkDoesNetworkIdExist(netId) then
                local ent = NetworkGetEntityFromNetworkId(netId)
                if DoesEntityExist(ent) then
                    DeleteEntity(ent)
                end
            end
        end
    end
    ActiveGroundSpeakers = {}

    if AttachedVehicleSpeakerProps then
        for _, prop in pairs(AttachedVehicleSpeakerProps) do
            if DoesEntityExist(prop) then
                DetachEntity(prop, true, true)
                DeleteEntity(prop)
            end
        end
    end
    AttachedVehicleSpeakerProps = {}

    if SpawnedPermanentProps then
        for _, ent in pairs(SpawnedPermanentProps) do
            if DoesEntityExist(ent) then
                DeleteEntity(ent)
            end
        end
    end
    SpawnedPermanentProps = {}
end)

-- ==========================================================
-- Exports de Itens Usáveis (ox_inventory) e Comandos Rápidos
-- ==========================================================

exports('usePortableRadio', function(data, slot)
    -- Infere o tipo de speaker a partir do nome do item (ox_inventory passa data.name)
    local itemName = (data and type(data) == 'table' and data.name) or (type(data) == 'string' and data) or 'radio_portable'
    local speakerType = 'retro' -- fallback
    if Config.General.SpeakerTypes then
        for typeId, typeData in pairs(Config.General.SpeakerTypes) do
            if typeData.item == itemName then
                speakerType = typeId
                break
            end
        end
    end
    TriggerEvent('vp_newspaper:client:openPortableRadioMenu', speakerType)
end)

exports('useHeadphones', function(data, slot)
    TriggerEvent('vp_newspaper:client:toggleHeadphones')
end)

RegisterCommand('weazelboombox', function()
    TriggerEvent('vp_newspaper:client:openPortableRadioMenu')
end, false)

RegisterCommand('caixadesom', function()
    TriggerEvent('vp_newspaper:client:openPortableRadioMenu')
end, false)

RegisterCommand('usarradio', function()
    TriggerEvent('vp_newspaper:client:openPortableRadioMenu')
end, false)

RegisterCommand('lojasom', function()
    OpenSpeakerShopMenu()
end, false)

-- ==========================================================
-- Loja de Caixas de Som (Rahe Speaker Shop Client)
-- ==========================================================

function OpenSpeakerShopMenu()
    if not Config.General.SpeakerTypes then return end

    local options = {}
    for typeId, data in pairs(Config.General.SpeakerTypes) do
        local priceStr = data.price and ('$%d'):format(data.price) or 'Grátis'
        options[#options + 1] = {
            title = (data.icon or '🔊') .. ' ' .. data.label .. ' — ' .. priceStr,
            description = ('%s\nAlcance: %.0fm | Potência: %d%% | Transporte: %s'):format(
                data.description or 'Caixa de Som',
                data.maxRange or 35.0,
                math.floor((data.maxVolume or 1.0) * 100),
                data.carryType == 'shoulder' and 'No Ombro' or 'Duas Mãos'
            ),
            icon = 'basket-shopping',
            onSelect = function()
                local alert = lib.alertDialog({
                    header = 'Confirmar Compra',
                    content = ('Deseja comprar o modelo **%s** por **%s**?'):format(data.label, priceStr),
                    centered = true,
                    cancel = true
                })
                if alert == 'confirm' then
                    local ok, res = lib.callback.await('vp_newspaper:server:purchaseSpeaker', false, typeId)
                    if ok then
                        lib.notify({
                            title = 'Loja de Caixas de Som',
                            description = ('Você comprou: **%s**! O item foi enviado ao seu inventário.'):format(res),
                            type = 'success'
                        })
                    else
                        lib.notify({
                            title = 'Falha na Compra',
                            description = res or 'Não foi possível concluir a compra.',
                            type = 'error'
                        })
                    end
                end
            end
        }
    end

    lib.registerContext({
        id = 'weazel_speaker_shop_menu',
        title = '🛒 Loja de Caixas de Som',
        options = options
    })
    lib.showContext('weazel_speaker_shop_menu')
end

RegisterNetEvent('vp_newspaper:client:openSpeakerShop', function()
    OpenSpeakerShopMenu()
end)

-- Spawner da Loja de Caixas de Som (NPC + Blip)
CreateThread(function()
    local shopCfg = Config.General.SpeakerShop
    if not shopCfg or not shopCfg.enabled then return end

    local coords = shopCfg.coords
    if shopCfg.blip and shopCfg.blip.enabled then
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, shopCfg.blip.sprite or 52)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, shopCfg.blip.scale or 0.75)
        SetBlipColour(blip, shopCfg.blip.color or 2)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(shopCfg.blip.name or 'Loja de Caixas de Som')
        EndTextCommandSetBlipName(blip)
    end

    local pedModel = shopCfg.pedModel or joaat('s_m_y_shop_mask')
    lib.requestModel(pedModel)
    local ped = CreatePed(4, pedModel, coords.x, coords.y, coords.z - 1.0, coords.w or 0.0, false, true)
    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addLocalEntity(ped, {
            {
                name = 'vp_newspaper_speaker_shop',
                icon = 'fa-solid fa-cart-shopping',
                label = 'Ver Catálogo de Caixas de Som',
                distance = 2.5,
                onSelect = function()
                    OpenSpeakerShopMenu()
                end
            }
        })
    end
end)

-- ==========================================================
-- Sincronização de Caixas Permanentes (Rahe Permanent Client)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:syncPermanentSpeakers', function(permanentData)
    PermanentSpeakers = permanentData or {}

    -- Limpa props antigos que foram removidos
    for permId, ent in pairs(SpawnedPermanentProps) do
        if not PermanentSpeakers[permId] and DoesEntityExist(ent) then
            DeleteEntity(ent)
            SpawnedPermanentProps[permId] = nil
        end
    end

    -- Spawna ou atualiza props no mundo
    for permId, data in pairs(PermanentSpeakers) do
        if not SpawnedPermanentProps[permId] or not DoesEntityExist(SpawnedPermanentProps[permId]) then
            local typeData = Config.General.SpeakerTypes and Config.General.SpeakerTypes[data.speakerType]
            local modelHash = (typeData and typeData.model) or joaat('prop_boombox_01')
            lib.requestModel(modelHash)

            local obj = CreateObject(modelHash, data.coords.x, data.coords.y, data.coords.z - 0.95, false, false, false)
            PlaceObjectOnGroundProperly(obj)
            SetEntityHeading(obj, data.heading or 0.0)
            FreezeEntityPosition(obj, true)

            -- Marca o state bag para interações
            Entity(obj).state:set('weazelPermanentSpeakerId', permId, false)
            SpawnedPermanentProps[permId] = obj

            if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
                exports.ox_target:addLocalEntity(obj, {
                    {
                        name = 'vp_newspaper_control_perm_speaker_' .. tostring(permId),
                        icon = 'fa-solid fa-music',
                        label = ('Controlar Som: %s'):format(data.name or 'Caixa Permanente'),
                        distance = 3.0,
                        onSelect = function()
                            OpenSpeakerControlMenu('perm_' .. tostring(permId), 'permanent')
                        end
                    }
                })
            end
        end
    end
end)

RegisterCommand('lojasom', function()
    OpenSpeakerShopMenu()
end, false)

