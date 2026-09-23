-- ==========================================================
-- vp_newspaper: Newspaper Editor NUI & Page Builder
-- ==========================================================

local isEditorOpen = false

-- Abertura da bancada de edição da redação
RegisterNetEvent('clen:openUI', function(pageData)
    if not pageData or not pageData[1] then return end

    isEditorOpen = true

    -- Envia textos localizados para a NUI
    SendNUIMessage({
        type = 'locales',
        texts = NMLocales.Texts[NMLocales.CurrentLanguage]
    })

    -- Abre o editor visual
    SendNUIMessage({
        type = 'open',
        texts = pageData[1].general,
        general = Config.General
    })

    SetNuiFocus(true, true)
end)

-- Mudança de página no modo de edição
RegisterNetEvent('clen:changePage', function(pageContent)
    if not pageContent then return end

    SendNUIMessage({
        type = 'changePage',
        texts = pageContent
    })

    SendNUIMessage({
        type = 'playSound',
        transactionFile = 'swap',
        transactionVolume = 0.2
    })
end)

-- ==========================================================
-- NUI Callbacks do Editor Visual
-- ==========================================================

RegisterNUICallback('rybuterol_NUICallback_Kayit', function(data, cb)
    if data and data.cb and data.page then
        TriggerServerEvent('clen:saveTexts', data.cb, data.page)
    end
    cb('ok')
end)

RegisterNUICallback('rybuterol_NUICallback_Sil', function(data, cb)
    if data and data.id and data.page then
        TriggerServerEvent('clen:removeText', data.id, data.page)
    end
    cb('ok')
end)

RegisterNUICallback('rybuterol_NUICallback_HepsiniSil', function(data, cb)
    if data and data.page then
        TriggerServerEvent('clen:removeTextAll', data.page)
    end
    cb('ok')
end)
