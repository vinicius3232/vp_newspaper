-- ============================================================================
-- vp_newspaper: Jornalismo de Campo & Pautas de Notícia (Client)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local spawnedPeds = {}

local function CleanupFieldPeds()
    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    spawnedPeds = {}
end

local function StartSpotCoverage(spot)
    local animDict = 'missheistdocksprep1hold_cellphone'
    local animClip = 'hold_cellphone'

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end

    TaskPlayAnim(cache.ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)

    local success = lib.progressBar({
        duration = 5000,
        label = ('Gravando cobertura: %s...'):format(spot.name),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    ClearPedTasks(cache.ped)

    if not success then
        lib.notify({ title = 'Jornalismo de Campo', description = 'Entrevista cancelada.', type = 'inform' })
        return
    end

    local res = lib.callback.await('vp_newspaper:server:completeFieldSpot', false, spot.id)
    if res and res.success then
        lib.alertDialog({
            header = '🎙️ Pauta Gravada com Sucesso!',
            content = ('**Manchete Investigativa Obtida:**\n"%s"\n\n**Recompensa:** +$%d em dinheiro.\n\n_Esta pauta foi salva e pode ser consultada via `/pautas` ou usada ao redigir uma matéria._'):format(res.headline, res.reward),
            centered = true,
            cancel = false,
        })
    else
        lib.notify({
            title = 'Jornalismo de Campo',
            description = (res and res.message) or 'Não foi possível concluir a pauta.',
            type = 'error',
        })
    end
end

local function InitializeFieldSpots()
    local cfg = Config.General.FieldJournalism
    if not cfg or not cfg.enabled then return end

    for _, spot in ipairs(cfg.spots) do
        local model = joaat(spot.npcModel or 'a_m_m_business_01')
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(50)
        end

        local ped = CreatePed(4, model, spot.coords.x, spot.coords.y, spot.coords.z - 1.0, spot.heading or 0.0, false, true)
        SetEntityAsMissionEntity(ped, true, true)
        SetBlockingOfNonTemporaryEvents(ped, true)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        table.insert(spawnedPeds, ped)

        if exports.ox_target then
            exports.ox_target:addLocalEntity(ped, {
                {
                    name = 'vp_field_spot_' .. spot.id,
                    icon = 'fa-solid fa-microphone-lines',
                    label = ('Gravar %s'):format(spot.name),
                    distance = 2.5,
                    onSelect = function()
                        StartSpotCoverage(spot)
                    end,
                }
            })
        end
    end
end

-- ============================================================================
-- Menu: Consulta de Pautas Ativas (/pautas)
-- ============================================================================
RegisterCommand('pautas', function()
    local leads = lib.callback.await('vp_newspaper:server:getPlayerLeads', false)
    if not leads or #leads == 0 then
        lib.notify({
            title = 'Pautas Weazel',
            description = 'Você não possui pautas ativas no momento. Visite pontos de cobertura pela cidade!',
            type = 'inform',
        })
        return
    end

    local options = {}
    for _, l in ipairs(leads) do
        table.insert(options, {
            title = l.headline_seed or 'Pauta de Notícia',
            description = ('Tipo: %s | Protocolo: %s'):format(l.spot_type, l.lead_id),
        })
    end

    lib.registerContext({
        id = 'vp_reporter_leads_menu',
        title = '📋 Suas Pautas de Reportagem Ativas',
        options = options,
    })
    lib.showContext('vp_reporter_leads_menu')
end, false)

CreateThread(function()
    Wait(2000)
    InitializeFieldSpots()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        CleanupFieldPeds()
    end
end)
