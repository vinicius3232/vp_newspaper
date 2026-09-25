-- ==========================================================
-- vp_newspaper: Vehicle Speaker Attachment (Client)
-- Inspired by Rahe Speakers Vehicle Sound Systems
-- ==========================================================

local AttachedSpeakerEntities = {} -- [vehNetId] = propEntity

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

---Acopla visualmente o prop do alto-falante ao veículo
---@param veh number
---@param vehNetId number
---@param pointName string
local function AttachSpeakerProp(veh, vehNetId, pointName)
    if AttachedSpeakerEntities[vehNetId] and DoesEntityExist(AttachedSpeakerEntities[vehNetId]) then
        return
    end

    local cfg = ATTACH_CONFIGS[pointName] or ATTACH_CONFIGS.trunk
    local propModel = Config.General.Radio and Config.General.Radio.portableProp or joaat('prop_boombox_01')

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
    AttachedSpeakerEntities[vehNetId] = prop
end

---Remove o prop do alto-falante acoplado ao veículo
---@param vehNetId number
local function DetachSpeakerProp(vehNetId)
    local prop = AttachedSpeakerEntities[vehNetId]
    if prop and DoesEntityExist(prop) then
        DetachEntity(prop, true, true)
        DeleteEntity(prop)
    end
    AttachedSpeakerEntities[vehNetId] = nil
end

---Abre menu interativo para instalar sistema de som no veículo
local function OpenInstallSpeakerMenu(veh)
    local vehNetId = NetworkGetNetworkIdFromEntity(veh)
    local hasSpeaker = Entity(veh).state.weazelVehicleSpeaker ~= nil

    if hasSpeaker then
        lib.registerContext({
            id = 'weazel_vehicle_speaker_manage',
            title = 'Sistema de Som Veicular',
            options = {
                {
                    title = 'Desinstalar Caixa de Som',
                    description = 'Remove o equipamento e guarda na mochila',
                    icon = 'box-archive',
                    onSelect = function()
                        local ok, err = lib.callback.await('vp_newspaper:server:detachSpeakerFromVehicle', false, vehNetId)
                        if ok then
                            lib.notify({ title = 'Som Veicular', description = 'Sistema de som desinstalado com sucesso!', type = 'success' })
                        else
                            lib.notify({ title = 'Som Veicular', description = err or 'Falha ao desinstalar!', type = 'error' })
                        end
                    end
                },
                {
                    title = 'Sintonizar Weazel Radio 98.5 FM',
                    description = 'Abre o controle de rádio e volume para este veículo',
                    icon = 'radio',
                    onSelect = function()
                        ExecuteCommand('weazelradio')
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
                description = 'Ideal para som automotivo e encontros de carros',
                icon = 'car-rear',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'trunk')
                end
            },
            {
                title = 'Instalar no Teto / Rack',
                description = 'Ideal para utilitários, vans e caminhonetes',
                icon = 'roof',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'roof')
                end
            },
            {
                title = 'Instalar na Caçamba',
                description = 'Ideal para pick-ups e carretas abertas',
                icon = 'truck-pickup',
                onSelect = function()
                    InstallSpeakerAction(veh, vehNetId, 'bed')
                end
            }
        }
    })
    lib.showContext('weazel_vehicle_speaker_install')
end

---Executa a ação física de instalação com barra de progresso
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

    local ok, res = lib.callback.await('vp_newspaper:server:attachSpeakerToVehicle', false, vehNetId, point)
    if ok then
        lib.notify({
            title = '🔊 Som Veicular Instalado',
            description = 'Caixa acoplada com sucesso! Controle a música pelo /weazelradio.',
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

-- ==========================================================
-- Sincronização via Eventos e StateBags
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:syncVehicleSpeaker', function(vehNetId, speakerData)
    local veh = NetworkDoesNetworkIdExist(vehNetId) and NetworkGetEntityFromNetworkId(vehNetId) or nil
    if not veh or not DoesEntityExist(veh) then return end

    if speakerData then
        AttachSpeakerProp(veh, vehNetId, speakerData.point)
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

-- Integração com ox_target em veículos
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

                -- Se não tem instalado, verifica se o player possui caixa de som portátil
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
end)

-- Limpeza ao parar o recurso
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    for netId, _ in pairs(AttachedSpeakerEntities) do
        DetachSpeakerProp(netId)
    end
    AttachedSpeakerEntities = {}
end)
