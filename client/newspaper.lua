-- ==========================================================
-- vp_newspaper: Newspaper Reader & Common NUI Handlers
-- ==========================================================

local isNewspaperOpen = false

---Abre a NUI de leitura do jornal
RegisterNetEvent('vp_newspaper:client:openReader', function()
    if isNewspaperOpen then return end
    TriggerServerEvent('vp_newspaper:server:openReader')
end)

exports('useNewspaper', function(data, slot)
    if isNewspaperOpen then return end
    TriggerServerEvent('vp_newspaper:server:openReader')
end)

-- Evento vindo do servidor para carregar o leitor
RegisterNetEvent('clen:openUIview', function(pageData)
    if not pageData or not pageData[1] then return end

    isNewspaperOpen = true

    -- Envia textos localizados
    SendNUIMessage({
        type = 'locales',
        texts = NMLocales.Texts[NMLocales.CurrentLanguage]
    })

    -- Abre o leitor
    SendNUIMessage({
        type = 'openView',
        texts = pageData[1].general,
        general = Config.General
    })

    SetNuiFocus(true, true)

    -- Animação de leitura de jornal
    local ped = PlayerPedId()
    lib.requestAnimDict('missfam4')
    TaskPlayAnim(ped, 'missfam4', 'base', 2.0, 2.0, -1, 49, 0, false, false, false)
end)

-- Mudança de página no modo de leitura
RegisterNetEvent('clen:changePageView', function(pageContent)
    if not pageContent then return end

    SendNUIMessage({
        type = 'changePageView',
        texts = pageContent
    })

    SendNUIMessage({
        type = 'playSound',
        transactionFile = 'swap',
        transactionVolume = 0.2
    })
end)

-- ==========================================================
-- NUI Callbacks Comuns (Fechar, Navegar, Notificar)
-- ==========================================================

RegisterNUICallback('exit', function(data, cb)
    SetNuiFocus(false, false)
    isNewspaperOpen = false
    ClearPedTasks(PlayerPedId())
    cb('ok')
end)

local function HandlePageChange(data, cb)
    if data and data.page then
        TriggerServerEvent('changePage', data.page)
    end
    cb('ok')
end

local function HandleNotify(data, cb)
    if data and data.notify then
        local msg = _U(data.notify) or data.notify
        TriggerEvent('vp_newspaper:client:notify', msg, 'info')
    end
    cb('ok')
end

RegisterNUICallback('changePage', HandlePageChange)
RegisterNUICallback('rybuterol_NUICallback_SayfaDegis', HandlePageChange)

RegisterNUICallback('notify', HandleNotify)
RegisterNUICallback('rybuterol_NUICallback_notify', HandleNotify)
