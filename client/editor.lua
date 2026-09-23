-- ==========================================================
-- vp_newspaper: Hardened Newspaper Editor & Heartbeat
-- ==========================================================

local isEditorOpen = false
local currentSessionId = nil
local currentRevision = 1
local heartbeatThread = false

-- Abertura da bancada de edição da redação
RegisterNetEvent('clen:openUI', function(pageData, sessionId)
    if not pageData or not pageData[1] then return end

    isEditorOpen = true
    currentSessionId = sessionId
    currentRevision = pageData[1].revision or 1

    -- Inicia heartbeat enquanto o editor estiver aberto
    if not heartbeatThread then
        heartbeatThread = true
        CreateThread(function()
            while isEditorOpen and currentSessionId do
                Wait(30000) -- Heartbeat a cada 30 segundos
                if isEditorOpen and currentSessionId then
                    TriggerServerEvent('vp_newspaper:server:editorHeartbeat', currentSessionId)
                end
            end
            heartbeatThread = false
        end)
    end

    -- Envia textos localizados para a NUI
    SendNUIMessage({
        type = 'locales',
        texts = NMLocales.Texts[NMLocales.CurrentLanguage]
    })

    -- Abre o editor visual
    SendNUIMessage({
        type = 'open',
        texts = pageData[1].general,
        general = Config.General,
        revision = currentRevision
    })

    SetNuiFocus(true, true)
end)

-- Mudança de página no modo de edição
RegisterNetEvent('clen:changePage', function(pageContent, newRevision)
    if not pageContent then return end
    currentRevision = newRevision or (currentRevision + 1)

    SendNUIMessage({
        type = 'changePage',
        texts = pageContent,
        revision = currentRevision
    })

    SendNUIMessage({
        type = 'playSound',
        transactionFile = 'swap',
        transactionVolume = 0.2
    })
end)

-- ==========================================================
-- NUI Callbacks do Editor Visual com OCC e Heartbeat
-- ==========================================================

local function HandleSavePage(data, cb)
    if data and data.cb and data.page then
        TriggerServerEvent('clen:saveTexts', data.cb, data.page, currentRevision)
    end
    cb('ok')
end

local function HandleDeleteElement(data, cb)
    if data and data.id and data.page then
        TriggerServerEvent('clen:removeText', data.id, data.page)
    end
    cb('ok')
end

local function HandleClearPage(data, cb)
    if data and data.page then
        TriggerServerEvent('clen:removeTextAll', data.page)
    end
    cb('ok')
end

RegisterNUICallback('savePage', HandleSavePage)
RegisterNUICallback('rybuterol_NUICallback_Kayit', HandleSavePage)

RegisterNUICallback('deleteElement', HandleDeleteElement)
RegisterNUICallback('rybuterol_NUICallback_Sil', HandleDeleteElement)

RegisterNUICallback('clearPage', HandleClearPage)
RegisterNUICallback('rybuterol_NUICallback_HepsiniSil', HandleClearPage)

-- Fechamento do editor
RegisterNUICallback('exit2', function(data, cb)
    SetNuiFocus(false, false)
    isEditorOpen = false
    currentSessionId = nil
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('nproblem_newspaper_isEditorActive2')
    cb('ok')
end)
RegisterNUICallback('closeEditor', function(data, cb)
    SetNuiFocus(false, false)
    isEditorOpen = false
    currentSessionId = nil
    ClearPedTasks(PlayerPedId())
    TriggerServerEvent('nproblem_newspaper_isEditorActive2')
    cb('ok')
end)
