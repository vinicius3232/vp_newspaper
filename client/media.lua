-- ==========================================================
-- vp_newspaper: Media Kit (Camera, Mic, Boom & Breaking News)
-- ==========================================================

local currentEquipment = nil
local activeProp = nil
local isInViewfinder = false
local viewfinderCam = nil
local currentFov = 60.0
local minFov, maxFov = 10.0, 70.0

-- ==========================================================
-- Gerenciamento de Props e Animações
-- ==========================================================

local function DetachCurrentEquipment()
    if activeProp and DoesEntityExist(activeProp) then
        DeleteEntity(activeProp)
        activeProp = nil
    end

    local ped = PlayerPedId()
    ClearPedTasks(ped)
    currentEquipment = nil

    if isInViewfinder then
        ExitViewfinderMode()
    end
end

local function EquipItem(equipType)
    local conf = Config.General.Media and Config.General.Media.props and Config.General.Media.props[equipType]
    if not conf then return end

    if currentEquipment == equipType then
        DetachCurrentEquipment()
        TriggerEvent('vp_newspaper:client:notify', 'Equipamento guardado.', 'info')
        return
    end

    DetachCurrentEquipment()

    local ped = PlayerPedId()
    local modelHash = joaat(conf.model)
    lib.requestModel(modelHash)
    lib.requestAnimDict(conf.animDict)

    local pCoords = GetEntityCoords(ped)
    local prop = CreateObject(modelHash, pCoords.x, pCoords.y, pCoords.z, true, true, false)
    SetEntityCollision(prop, false, false)
    SetEntityInvincible(prop, true)

    local boneIndex = GetPedBoneIndex(ped, conf.bone)
    AttachEntityToEntity(
        prop,
        ped,
        boneIndex,
        conf.offset.x, conf.offset.y, conf.offset.z,
        conf.rot.x, conf.rot.y, conf.rot.z,
        true, true, false, true, 1, true
    )

    TaskPlayAnim(ped, conf.animDict, conf.animClip, 2.0, -8.0, -1, 49, 0, false, false, false)

    activeProp = prop
    currentEquipment = equipType

    if equipType == 'camera' then
        lib.showTextUI('[E] Olhar no Visor da Câmera | [/cam] Guardar', {
            icon = 'fas fa-video',
            position = 'left-center'
        })
    else
        TriggerEvent('vp_newspaper:client:notify', 'Equipamento empunhado com sucesso!', 'success')
    end
end

RegisterNetEvent('vp_newspaper:client:toggleEquipment', function(equipType)
    EquipItem(equipType)
end)

-- ==========================================================
-- Modo Visor da Câmera (Viewfinder HUD + Zoom Óptico FOV)
-- ==========================================================

function ExitViewfinderMode()
    if not isInViewfinder then return end
    isInViewfinder = false

    if viewfinderCam and DoesCamExist(viewfinderCam) then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(viewfinderCam, false)
        viewfinderCam = nil
    end

    ClearTimecycleModifier()
    DisplayRadar(true)

    if currentEquipment == 'camera' then
        lib.showTextUI('[E] Olhar no Visor da Câmera | [/cam] Guardar', {
            icon = 'fas fa-video',
            position = 'left-center'
        })
    else
        lib.hideTextUI()
    end
end

local function EnterViewfinderMode()
    if isInViewfinder then return end
    isInViewfinder = true
    lib.hideTextUI()
    DisplayRadar(false)

    local ped = PlayerPedId()
    currentFov = 60.0

    viewfinderCam = CreateCam('DEFAULT_SCRIPTED_FLY_CAMERA', true)
    AttachCamToPedBone(viewfinderCam, ped, 31086, 0.0, 0.25, 0.1, true) -- SKEL_Head
    SetCamFov(viewfinderCam, currentFov)
    RenderScriptCams(true, false, 0, true, true)

    SetTimecycleModifier('default')
    SetTimecycleModifierStrength(0.3)

    CreateThread(function()
        local recAlpha = 255
        local recTick = 0

        while isInViewfinder do
            Wait(0)
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 14, true) -- Weapon Wheel
            DisableControlAction(0, 15, true) -- Weapon Wheel Next

            local pHeading = GetEntityHeading(ped)
            local pPitch = GetGameplayCamRelativePitch()
            SetCamRot(viewfinderCam, pPitch, 0.0, pHeading, 2)

            -- Zoom óptico com Scroll do Mouse
            if IsControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 241) then -- Scroll Up (Zoom In)
                currentFov = math.max(minFov, currentFov - 5.0)
                SetCamFov(viewfinderCam, currentFov)
            elseif IsControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 242) then -- Scroll Down (Zoom Out)
                currentFov = math.min(maxFov, currentFov + 5.0)
                SetCamFov(viewfinderCam, currentFov)
            end

            -- Overlay HUD do Visor
            recTick = recTick + 1
            if recTick % 30 == 0 then
                recAlpha = (recAlpha == 255) and 40 or 255
            end

            -- Ícone REC Piscante
            DrawRect(0.12, 0.08, 0.015, 0.015, 255, 0, 0, recAlpha)
            SetTextFont(0)
            SetTextProportional(true)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 255)
            SetTextDropshadow(1, 0, 0, 0, 255)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('REC  WEAZEL NEWS LIVE')
            EndTextCommandDisplayText(0.135, 0.07)

            -- Nível de Zoom
            local zoomPct = math.floor((1.0 - ((currentFov - minFov) / (maxFov - minFov))) * 100)
            SetTextFont(0)
            SetTextProportional(true)
            SetTextScale(0.35, 0.35)
            SetTextColour(255, 255, 255, 220)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('ZOOM: %d%%  |  FOV: %.1f'):format(zoomPct, currentFov))
            EndTextCommandDisplayText(0.80, 0.07)

            -- Oculta HUD padrão e radar
            HideHudAndRadarThisFrame()

            -- Barras Cinematográficas Letterbox (Broadcast Format)
            DrawRect(0.5, 0.025, 1.0, 0.05, 0, 0, 0, 255)
            DrawRect(0.5, 0.975, 1.0, 0.05, 0, 0, 0, 255)

            -- Linha de Grade Central (Retículo de Foco)
            DrawRect(0.5, 0.5, 0.02, 0.002, 255, 255, 255, 120)
            DrawRect(0.5, 0.5, 0.002, 0.02, 255, 255, 255, 120)

            -- Rodapé de Instrução
            SetTextFont(0)
            SetTextProportional(true)
            SetTextScale(0.30, 0.30)
            SetTextColour(200, 200, 200, 180)
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName('[SCROLL] Zoom  |  [E / BACKSPACE] Sair do Visor')
            EndTextCommandDisplayText(0.40, 0.94)

            -- Sair do visor
            if IsControlJustPressed(0, 38) or IsControlJustPressed(0, 177) then
                ExitViewfinderMode()
                break
            end
        end
    end)
end

-- Monitoramento do Teclado para Abrir o Visor da Câmera
CreateThread(function()
    while true do
        local sleep = 500
        if currentEquipment == 'camera' and not isInViewfinder then
            sleep = 0
            if IsControlJustPressed(0, 38) then -- E
                EnterViewfinderMode()
            end
        end
        Wait(sleep)
    end
end)

-- ==========================================================
-- Scaleform Nativo de Plantão Urgente (BREAKING_NEWS)
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:displayBreakingNews', function(headline, subtitle, durationMs)
    durationMs = durationMs or 9000

    -- Interceptação de Rádio: Reduz a música da Weazel Radio e toca o alerta
    SendNUIMessage({ action = 'attenuate', factor = 0.15 })

    -- Toca vinheta de alerta ao vivo
    if Config.General.Media and Config.General.Media.breakingNews.sound then
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
    end

    local scaleform = RequestScaleformMovie('BREAKING_NEWS')
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(10)
    end

    -- Configuração dos Textos no Scaleform
    BeginScaleformMovieMethod(scaleform, 'SET_TEXT')
    PushScaleformMovieMethodParameterString(subtitle or 'Cobertura Ao Vivo da Cidade')
    PushScaleformMovieMethodParameterString('WEAZEL NEWS — PLANTÃO URGENTE')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'SET_SCROLL_TEXT')
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterString(string.upper(headline or 'NOTÍCIA DE ÚLTIMA HORA'))
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'DISPLAY_SCROLL_TEXT')
    PushScaleformMovieMethodParameterInt(0)
    PushScaleformMovieMethodParameterInt(0)
    EndScaleformMovieMethod()

    -- Loop de Renderização na Tela
    CreateThread(function()
        local endTime = GetGameTimer() + durationMs
        while GetGameTimer() < endTime do
            Wait(0)
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
        end
        SetScaleformMovieAsNoLongerNeeded(scaleform)
        SendNUIMessage({ action = 'restoreVolume' })
    end)
end)

-- ==========================================================
-- Limpeza e Salvaguardas
-- ==========================================================

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if activeProp then
            if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
                DetachCurrentEquipment()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    DetachCurrentEquipment()
    lib.hideTextUI()
end)
