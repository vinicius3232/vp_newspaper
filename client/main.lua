-- ==========================================================
-- vp_newspaper: Core Client, Zones, Garage & Management NUI
-- ==========================================================

local currentDeliveryVehicle = nil

-- ==========================================================
-- Sistema de Notificações Adaptativo
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:notify', function(msg, nType)
    nType = nType or 'info'
    if GetResourceState('lation_ui') == 'started' then
        exports.lation_ui:notify({
            title = 'Weazel News',
            message = msg,
            type = nType
        })
    elseif GetResourceState('ox_lib') == 'started' then
        lib.notify({
            title = 'Weazel News',
            description = msg,
            type = nType
        })
    else
        TriggerEvent('chat:addMessage', {
            color = { 255, 180, 0 },
            multiline = true,
            args = { 'Weazel News', msg }
        })
    end
end)

-- ==========================================================
-- Blips no Mapa
-- ==========================================================

CreateThread(function()
    local bConf = Config.Blips.weazelNews
    if bConf then
        local blip = AddBlipForCoord(bConf.coords.x, bConf.coords.y, bConf.coords.z)
        SetBlipSprite(blip, bConf.sprite)
        SetBlipDisplay(blip, bConf.display)
        SetBlipScale(blip, bConf.scale)
        SetBlipColour(blip, bConf.color)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(bConf.title)
        EndTextCommandSetBlipName(blip)
    end
end)

-- ==========================================================
-- Zonas de Interação ox_target (Weazel News Interior)
-- ==========================================================

CreateThread(function()
    if not Config.UseOxTarget or GetResourceState('ox_target') ~= 'started' then return end

    local coords = Config.General.Coords

    -- 1. Painel de Gestão (Boss)
    exports.ox_target:addSphereZone({
        coords = coords.managementCoord,
        radius = 1.2,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_management',
                icon = 'fas fa-briefcase',
                label = 'Painel de Gestão Weazel News',
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function()
                    TriggerServerEvent('vp_newspaper:server:requestManagementData')
                end
            }
        }
    })

    -- 2. Computador de Redação / Editor
    exports.ox_target:addSphereZone({
        coords = coords.editorCoord,
        radius = 1.2,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_editor',
                icon = 'fas fa-pen-nib',
                label = 'Computador da Redação (Editar Jornal)',
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function()
                    TriggerServerEvent('nproblem_newspaper_back')
                end
            }
        }
    })

    -- 3. Prensa Gráfica / Impressora
    exports.ox_target:addSphereZone({
        coords = coords.printerCoord,
        radius = 1.3,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_printer',
                icon = 'fas fa-print',
                label = 'Imprimir Tiragem de Jornais',
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function()
                    if lib.progressBar({
                        duration = 5000,
                        label = _U('printingProgress'),
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true },
                        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
                    }) then
                        TriggerServerEvent('vp_newspaper:server:printNewspapers')
                    end
                end
            }
        }
    })

    -- 4. Estoque de Papel em Branco
    exports.ox_target:addSphereZone({
        coords = coords.getPaperCoord,
        radius = 1.3,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_get_paper',
                icon = 'fas fa-scroll',
                label = 'Pegar Folhas de Papel em Branco',
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function()
                    if lib.progressBar({
                        duration = 3000,
                        label = _U('takingPaperProgress'),
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true },
                        anim = { dict = 'anim@mp_snowball', clip = 'pickup_snowball' }
                    }) then
                        TriggerServerEvent('vp_newspaper:server:getBlankPaper')
                    end
                end
            }
        }
    })

    -- 5. Garagem de Veículos de Distribuição
    exports.ox_target:addSphereZone({
        coords = coords.distributorCoord,
        radius = 1.5,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_spawn_van',
                icon = 'fas fa-van-shuttle',
                label = 'Retirar Van de Entrega (Weazel News)',
                distance = 2.5,
                groups = Config.General.jobName,
                onSelect = function()
                    SpawnDeliveryVehicle()
                end
            }
        }
    })

    -- 6. Devolver Veículo de Entrega
    exports.ox_target:addSphereZone({
        coords = Config.General.distributorPutVehicleCoord,
        radius = 3.0,
        debug = false,
        options = {
            {
                name = 'vp_newspaper_return_van',
                icon = 'fas fa-square-parking',
                label = 'Guardar Van de Entrega',
                distance = 4.0,
                onSelect = function()
                    ReturnDeliveryVehicle()
                end
            }
        }
    })
end)

-- ==========================================================
-- Spawner e Retorno do Veículo de Entrega
-- ==========================================================

function SpawnDeliveryVehicle()
    if currentDeliveryVehicle and DoesEntityExist(currentDeliveryVehicle) then
        TriggerEvent('vp_newspaper:client:notify', 'Você já retirou um veículo de entrega!', 'error')
        return
    end

    local spawns = Config.General.distributorCoords
    local chosenSpawn = spawns[1]

    -- Encontra ponto livre
    for _, sp in ipairs(spawns) do
        if not IsAnyVehicleNearPoint(sp.x, sp.y, sp.z, 2.5) then
            chosenSpawn = sp
            break
        end
    end

    local modelHash = joaat('rumpo')
    lib.requestModel(modelHash)

    local veh = CreateVehicle(modelHash, chosenSpawn.x, chosenSpawn.y, chosenSpawn.z, chosenSpawn.w, true, false)
    SetVehicleLivery(veh, 4) -- Weazel News Livery
    SetVehicleNumberPlateText(veh, 'WEAZEL' .. tostring(math.random(10, 99)))
    SetEntityAsMissionEntity(veh, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

    currentDeliveryVehicle = veh
    TriggerEvent('vp_newspaper:client:notify', _U('vehicleSpawned'), 'success')
end

function ReturnDeliveryVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then
        veh = currentDeliveryVehicle
    end

    if veh and DoesEntityExist(veh) then
        TaskLeaveVehicle(ped, veh, 0)
        Wait(1500)
        DeleteEntity(veh)
        currentDeliveryVehicle = nil
        TriggerEvent('vp_newspaper:client:notify', _U('vehicleReturned'), 'success')
    else
        TriggerEvent('vp_newspaper:client:notify', _U('notInVehicle'), 'error')
    end
end

-- ==========================================================
-- NUI de Gestão da Empresa (Dashboard, Saldo e Funcionários)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:openManagement', function(companyData)
    if not companyData then return end

    SendNUIMessage({
        type = 'locales',
        texts = NMLocales.Texts[NMLocales.CurrentLanguage]
    })

    SendNUIMessage({
        type = 'manager',
        data = companyData
    })

    SetNuiFocus(true, true)
end)

RegisterNetEvent('vp_newspaper:client:updateManagerData', function(companyData)
    if not companyData then return end
    SendNUIMessage({
        type = 'manager',
        data = companyData
    })
end)

RegisterNUICallback('databaseupdate', function(data, cb)
    if data and data.type and data.amount ~= nil then
        TriggerServerEvent('databaseupdate', data.type, data.amount)
    end
    cb('ok')
end)

RegisterNUICallback('iseal', function(data, cb)
    if data and data.id then
        TriggerServerEvent('nproblem_newspaper_iseal', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('fireupdown', function(data, cb)
    if data and data.id and data.tip then
        TriggerServerEvent('nproblem_newspaper_fireupdown', data.id, data.tip)
    end
    cb('ok')
end)
