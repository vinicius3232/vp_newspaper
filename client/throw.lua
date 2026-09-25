-- ============================================================================
-- vp_newspaper: Entrega Paperboy com Arremesso Físico (Client)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local isOnPaperboyRoute = false
local paperboyBike = nil
local routeBlips = {}
local lastThrowTime = 0

local function CleanupPaperboyRoute()
    isOnPaperboyRoute = false
    for _, b in ipairs(routeBlips) do
        if DoesBlipExist(b) then
            RemoveBlip(b)
        end
    end
    routeBlips = {}

    if paperboyBike and DoesEntityExist(paperboyBike) then
        DeleteEntity(paperboyBike)
        paperboyBike = nil
    end

    lib.notify({
        title = 'Paperboy Weazel',
        description = 'Rota de entregas finalizada.',
        type = 'inform',
    })
end

local function ThrowNewspaperAtTarget(target)
    local cfg = Config.General.Paperboy
    local now = GetGameTimer()
    if (now - lastThrowTime) < (cfg.throwCooldownMs or 2500) then
        lib.notify({ title = 'Paperboy', description = 'Aguarde para arremessar novamente.', type = 'warning' })
        return
    end

    lastThrowTime = now

    -- Animação de Arremesso
    local animDict = 'weapons@projectile@'
    local animClip = 'throw_m_fb'
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end

    TaskPlayAnim(cache.ped, animDict, animClip, 8.0, -8.0, -1, 48, 0, false, false, false)

    -- Prop Físico Arremessado
    local propModel = joaat('prop_cliff_paper')
    RequestModel(propModel)
    while not HasModelLoaded(propModel) do
        Wait(50)
    end

    local pedCoords = GetEntityCoords(cache.ped)
    local prop = CreateObject(propModel, pedCoords.x, pedCoords.y, pedCoords.z + 0.5, true, true, false)
    SetEntityVelocity(prop, (target.coords.x - pedCoords.x) * 1.5, (target.coords.y - pedCoords.y) * 1.5, 4.0)

    SetTimeout(1200, function()
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end)

    Wait(300)
    local res = lib.callback.await('vp_newspaper:server:processPaperboyThrow', false, target.id, target.coords)
    if res and res.success then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', true)
        lib.notify({
            title = 'Arremesso Certeiro!',
            description = ('Jornal entregue em **%s**!\n+**$%d** recebidos (%d/%d hoje).'):format(target.label, res.reward, res.deliveredCount, res.maxDaily),
            type = 'success',
        })
    else
        lib.notify({
            title = 'Paperboy',
            description = (res and res.message) or 'Falha no arremesso.',
            type = 'error',
        })
    end
end

local function StartPaperboyRoute()
    if isOnPaperboyRoute then
        CleanupPaperboyRoute()
        return
    end

    local cfg = Config.General.Paperboy
    if not cfg or not cfg.enabled then return end

    -- Spawn da Bicicleta
    local model = joaat(cfg.bikeModel or 'cruiser')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(50)
    end

    local spawn = cfg.spawnCoord or vector4(-552.0, -943.0, 23.85, 270.0)
    paperboyBike = CreateVehicle(model, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetEntityAsMissionEntity(paperboyBike, true, true)
    TaskWarpPedIntoVehicle(cache.ped, paperboyBike, -1)

    -- Marcação dos Alvos de Arremesso
    for _, t in ipairs(cfg.throwTargets) do
        local blip = AddBlipForCoord(t.coords.x, t.coords.y, t.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.7)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Entrega Paperboy: ' .. t.label)
        EndTextCommandSetBlipName(blip)
        table.insert(routeBlips, blip)
    end

    isOnPaperboyRoute = true
    lib.notify({
        title = 'Paperboy Weazel',
        description = 'Rota iniciada! Pedale até os pontos amarelos e pressione [E] para arremessar jornais.',
        type = 'success',
    })

    -- Thread de Monitoramento de Proximidade e Arremesso
    CreateThread(function()
        while isOnPaperboyRoute do
            local sleep = 1000
            local pedCoords = GetEntityCoords(cache.ped)
            local vehicle = GetVehiclePedIsIn(cache.ped, false)

            if vehicle ~= 0 then
                for _, t in ipairs(cfg.throwTargets) do
                    local dist = #(pedCoords - t.coords)
                    if dist <= (cfg.maxThrowDistance or 18.0) then
                        sleep = 0
                        DrawMarker(1, t.coords.x, t.coords.y, t.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.0, 2.0, 0.5, 255, 215, 0, 150, false, false, 2, false, nil, nil, false)
                        lib.showTextUI(('[E] Arremessar Jornal em %s'):format(t.label), { position = 'top-center' })

                        if IsControlJustPressed(0, 38) then -- Tecla E
                            lib.hideTextUI()
                            ThrowNewspaperAtTarget(t)
                            Wait(1000)
                        end
                        break
                    else
                        lib.hideTextUI()
                    end
                end
            else
                lib.hideTextUI()
            end
            Wait(sleep)
        end
        lib.hideTextUI()
    end)
end

-- Comando /paperboy para iniciar ou encerrar a rota
RegisterCommand('paperboy', function()
    StartPaperboyRoute()
end, false)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        CleanupPaperboyRoute()
    end
end)
