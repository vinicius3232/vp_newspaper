-- ==========================================================
-- vp_newspaper: Newspaper Reader & Scaleform Controls (1:1 NProbleM)
-- ==========================================================

local isNewspaperOpen = false
local currentReadPage = 1
local instructionalButtons = nil
local currentNewspaperProp = nil

---Abre a NUI de leitura do jornal
RegisterNetEvent('vp_newspaper:client:openReader', function()
    if isNewspaperOpen then return end
    TriggerServerEvent('vp_newspaper:server:openReader')
end)

exports('useNewspaper', function(data, slot)
    if isNewspaperOpen then return end
    TriggerServerEvent('vp_newspaper:server:openReader')
end)

local function PromptUnpackBox()
    local alert = lib.alertDialog({
        header = 'Desempacotar Jornais',
        content = 'Deseja abrir esta caixa e extrair 5 exemplares impressos para leitura e entrega individual?',
        centered = true,
        cancel = true,
        labels = {
            confirm = 'Abrir Caixa',
            cancel = 'Cancelar'
        }
    })
    if alert == 'confirm' then
        if lib.progressBar({
            duration = 3000,
            label = 'Desempacotando jornais...',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true },
            anim = { dict = 'anim@mp_player_intmenu@key_fob@', clip = 'fob_click' }
        }) then
            TriggerServerEvent('vp_newspaper:server:unpackNewspaperBox')
        end
    end
end

RegisterNetEvent('vp_newspaper:client:unpackBoxPrompt', PromptUnpackBox)
exports('useNewspaperBox', PromptUnpackBox)

local function StopNewspaperAnimation()
    if currentNewspaperProp and DoesEntityExist(currentNewspaperProp) then
        DeleteEntity(currentNewspaperProp)
        currentNewspaperProp = nil
    end
    ClearPedTasks(PlayerPedId())
end

local function StartNewspaperAnimation()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end

    lib.requestAnimDict('missfam4')
    TaskPlayAnim(ped, 'missfam4', 'base', 8.0, 8.0, -1, 49, 0, false, false, false)

    if not currentNewspaperProp or not DoesEntityExist(currentNewspaperProp) then
        local propHash = joaat('v_res_tabloidsb')
        lib.requestModel(propHash)
        local pCoords = GetEntityCoords(ped)
        local obj = CreateObject(propHash, pCoords.x, pCoords.y, pCoords.z, true, true, false)
        AttachEntityToEntity(
            obj,
            ped,
            GetPedBoneIndex(ped, 18905),
            0.15,
            0.15,
            -0.03,
            200.0,
            120.0,
            0.0,
            true,
            true,
            false,
            true,
            1,
            true
        )
        currentNewspaperProp = obj
    end
end

local function SetupInstructionalButtons()
    local scaleform = RequestScaleformMovie('instructional_buttons')
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end
    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 175, true)) -- Seta Direita
    BeginTextCommandScaleformString('STRING')
    AddTextComponentScaleform('Próxima Página')
    EndTextCommandScaleformString()
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
    PushScaleformMovieFunctionParameterInt(1)
    PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 174, true)) -- Seta Esquerda
    BeginTextCommandScaleformString('STRING')
    AddTextComponentScaleform('Página Anterior')
    EndTextCommandScaleformString()
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
    PushScaleformMovieFunctionParameterInt(2)
    PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(0, 177, true)) -- Backspace / ESC
    BeginTextCommandScaleformString('STRING')
    AddTextComponentScaleform('Fechar')
    EndTextCommandScaleformString()
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PopScaleformMovieFunctionVoid()
    return scaleform
end

local function CloseReader()
    if not isNewspaperOpen then return end
    isNewspaperOpen = false
    currentReadPage = 1
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'exit' })
    StopNewspaperAnimation()
    if instructionalButtons then
        SetScaleformMovieAsNoLongerNeeded(instructionalButtons)
        instructionalButtons = nil
    end
end

-- Thread interativa de leitura no estilo NProbleM (Scaleform, Setas e ESC)
CreateThread(function()
    while true do
        local sleep = 1000
        if isNewspaperOpen then
            sleep = 0
            if not instructionalButtons then
                instructionalButtons = SetupInstructionalButtons()
            end
            DrawScaleformMovieFullscreen(instructionalButtons, 255, 255, 255, 255, 0)

            -- Intercepta controles para evitar que a tecla ESC abra o Pause Menu do GTA V
            DisableControlAction(0, 199, true) -- Pause Menu
            DisableControlAction(0, 200, true) -- Pause Menu Alternate (ESC)
            DisableControlAction(0, 177, true) -- Backspace
            DisableControlAction(0, 24, true)  -- Attack
            DisableControlAction(0, 25, true)  -- Aim

            local ped = PlayerPedId()
            if IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsEntityDead(ped) then
                CloseReader()
            elseif not IsEntityPlayingAnim(ped, 'missfam4', 'base', 3) then
                StartNewspaperAnimation()
            end

            -- Controles: Seta Direita (175) -> Próxima
            if IsControlJustPressed(0, 175) then
                local maxP = (Config.General and Config.General.allowedMaxPage) or 5
                if currentReadPage < maxP then
                    currentReadPage = currentReadPage + 1
                    TriggerServerEvent('changePageView', currentReadPage)
                end
            -- Seta Esquerda (174) -> Anterior
            elseif IsControlJustPressed(0, 174) then
                if currentReadPage > 1 then
                    currentReadPage = currentReadPage - 1
                    TriggerServerEvent('changePageView', currentReadPage)
                end
            -- ESC (200 / 199), Backspace (177) ou Botão Direito do Mouse (25) -> Fechar
            elseif IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 177)
                or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)
                or IsControlJustPressed(0, 199) or IsDisabledControlJustPressed(0, 199)
                or IsControlJustPressed(0, 25) or IsDisabledControlJustPressed(0, 25) then
                CloseReader()
            end
        else
            if instructionalButtons then
                SetScaleformMovieAsNoLongerNeeded(instructionalButtons)
                instructionalButtons = nil
            end
        end
        Wait(sleep)
    end
end)

-- Comandos de contingência caso o jogador precise forçar fechamento
RegisterCommand('fecharleitor', CloseReader, false)
RegisterCommand('destravarleitor', CloseReader, false)

-- Evento vindo do servidor para carregar o leitor
RegisterNetEvent('clen:openUIview', function(pageData)
    if not pageData or not pageData[1] then return end

    isNewspaperOpen = true
    currentReadPage = 1

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

    -- No NProbleM, a navegação de leitura usa SetNuiFocus(false, false) para o jogador folhear pelas setas
    SetNuiFocus(false, false)
    StartNewspaperAnimation()
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
    CloseReader()
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CloseReader()
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
