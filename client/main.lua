-- ==========================================================
-- vp_newspaper: Core Client, Zones, Garage & Management NUI
-- ==========================================================

CurrentDeliveryVehicle = nil

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
                label = 'Operar Prensa Gráfica',
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function()
                    lib.registerContext({
                        id = 'vp_newspaper_printer_menu',
                        title = 'Prensa Gráfica Weazel News',
                        options = {
                            {
                                title = 'Imprimir Exemplar para Leitura',
                                description = 'Consome 1 folha de papel e entrega 1 jornal pronto para ler.',
                                icon = 'newspaper',
                                onSelect = function()
                                    local ped = PlayerPedId()
                                    TaskGoStraightToCoord(ped, -577.39, -938.04, 23.88, 1.0, 2000, 92.76, 0.2)
                                    Wait(1500)
                                    if lib.progressBar({
                                        duration = 3500,
                                        label = 'Imprimindo exemplar de leitura...',
                                        useWhileDead = false,
                                        canCancel = true,
                                        disable = { car = true, move = true },
                                        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
                                    }) then
                                        TriggerServerEvent('vp_newspaper:server:printSingleNewspaper')
                                    end
                                end
                            },
                            {
                                title = 'Imprimir Caixa de Jornais (Tiragem)',
                                description = 'Consome 5 folhas de papel e gera 1 caixa para abastecer bancas.',
                                icon = 'boxes-stacked',
                                onSelect = function()
                                    local ped = PlayerPedId()
                                    TaskGoStraightToCoord(ped, -577.39, -938.04, 23.88, 1.0, 2000, 92.76, 0.2)
                                    Wait(1500)
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
                    lib.showContext('vp_newspaper_printer_menu')
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
    if CurrentDeliveryVehicle and DoesEntityExist(CurrentDeliveryVehicle) then
        TriggerEvent('vp_newspaper:client:notify', 'Você já retirou um veículo de entrega!', 'error')
        return
    end

    local vehicles = Config.General.distributorVehicles or { 'rumpo' }
    if #vehicles > 1 and GetResourceState('ox_lib') == 'started' then
        local options = {}
        for _, vModel in ipairs(vehicles) do
            options[#options + 1] = {
                title = string.upper(vModel),
                description = 'Retirar veículo Weazel News',
                icon = 'van-shuttle',
                onSelect = function()
                    TriggerServerEvent('vp_newspaper:server:spawnDeliveryVehicle', vModel)
                end
            }
        end
        lib.registerContext({
            id = 'vp_newspaper_vehicle_selector',
            title = 'Frota de Distribuição',
            options = options
        })
        lib.showContext('vp_newspaper_vehicle_selector')
    else
        TriggerServerEvent('vp_newspaper:server:spawnDeliveryVehicle', vehicles[1] or 'rumpo')
    end
end

RegisterNetEvent('vp_newspaper:client:deliveryVehicleSpawned', function(netId, chosenModel)
    local waitCount = 0
    while not NetworkDoesNetworkIdExist(netId) and waitCount < 30 do
        Wait(100)
        waitCount = waitCount + 1
    end

    local veh = NetToVeh(netId)
    if DoesEntityExist(veh) then
        CurrentDeliveryVehicle = veh
        local livery = 4
        if Config.General.distributorVehicleLiveries and chosenModel and Config.General.distributorVehicleLiveries[chosenModel] then
            livery = Config.General.distributorVehicleLiveries[chosenModel]
        end
        SetVehicleLivery(veh, livery) -- Weazel News Livery
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)

        -- Destaque visual: Aura azul para localização do veículo
        SetEntityDrawOutline(veh, true)
        SetEntityDrawOutlineColor(50, 50, 255, 255)

        CreateThread(function()
            while CurrentDeliveryVehicle and DoesEntityExist(veh) do
                Wait(500)
                if IsPedInVehicle(PlayerPedId(), veh, false) then
                    SetEntityDrawOutline(veh, false)
                    break
                end
            end
        end)
    end
end)

function ReturnDeliveryVehicle()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 0)
        Wait(1200)
    end

    TriggerServerEvent('vp_newspaper:server:returnDeliveryVehicle')
end

RegisterNetEvent('vp_newspaper:client:deliveryVehicleReturned', function()
    CurrentDeliveryVehicle = nil
end)

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

-- ==========================================================
-- Comandos Diretos de Gestão, Leitura e Produção (NProbleM Flow)
-- ==========================================================

RegisterCommand('gestaojornal', function()
    TriggerServerEvent('vp_newspaper:server:requestManagementData')
end, false)

RegisterCommand('weazelboss', function()
    TriggerServerEvent('vp_newspaper:server:requestManagementData')
end, false)

RegisterCommand('lerjornal', function()
    TriggerServerEvent('vp_newspaper:server:openReader')
end, false)

RegisterCommand('imprimirjornal', function()
    local ped = PlayerPedId()
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
end, false)

RegisterCommand('pegapapel', function()
    TriggerServerEvent('vp_newspaper:server:takePaper')
end, false)
