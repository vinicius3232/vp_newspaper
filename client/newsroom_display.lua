-- ==========================================================
-- vp_newspaper: Newsroom Live Display (3D DUI Monitor)
-- Renders a 3D digital broadcast screen in Weazel News MLO
-- Audited and Hardened against Memory Leaks & Resmon
-- ==========================================================

local newsroomPoint = nil
local activeDuiObj = nil
local activeDuiHandle = nil
local runtimeTxdCreated = false
local txdName = 'vp_newsroom_txd'
local txnName = 'live_screen'

local currentDisplayData = {
    title = 'WEAZEL NEWS: A VERDADE EM TEMPO REAL',
    subtitle = 'Redação Central de Los Santos — Plantão 24 Horas',
    category = 'Noticiário Central',
    boxesCount = 5,
    isBreaking = false,
    tickerText = '+++ WEAZEL NEWS 98.5 FM NO AR +++ COBERTURA COMPLETA DE SAN ANDREAS +++ INFORMAÇÕES DA REDAÇÃO CENTRAL +++'
}

---Desenha o quad 3D do monitor na parede usando DrawSpritePoly
---@param coords vector3
---@param heading number
---@param width number
---@param height number
---@param curTxd string
---@param curTxn string
local function DrawScreenQuad(coords, heading, width, height, curTxd, curTxn)
    local rad = math.rad(heading)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0) * (width * 0.5)
    local up = vector3(0.0, 0.0, 1.0) * (height * 0.5)

    local TL = coords - right + up
    local TR = coords + right + up
    local BL = coords - right - up
    local BR = coords + right - up

    -- Triângulo 1 (Superior-Esquerdo)
    DrawSpritePoly(
        TL.x, TL.y, TL.z,
        TR.x, TR.y, TR.z,
        BL.x, BL.y, BL.z,
        255, 255, 255, 255,
        curTxd, curTxn,
        0.0, 0.0, 1.0,
        1.0, 0.0, 1.0,
        0.0, 1.0, 1.0
    )

    -- Triângulo 2 (Inferior-Direito)
    DrawSpritePoly(
        TR.x, TR.y, TR.z,
        BR.x, BR.y, BR.z,
        BL.x, BL.y, BL.z,
        255, 255, 255, 255,
        curTxd, curTxn,
        1.0, 0.0, 1.0,
        1.0, 1.0, 1.0,
        0.0, 1.0, 1.0
    )
end

---Envia atualização de dados para a página DUI via SendDuiMessage
---@param payload table
local function PushDataToDui(payload)
    if not activeDuiObj then return end
    SendDuiMessage(activeDuiObj, json.encode({
        type = 'UPDATE_NEWSROOM',
        payload = payload
    }))
end

---Destrói o DUI de forma limpa e segura
local function CleanupDui()
    if activeDuiObj then
        SetDuiUrl(activeDuiObj, 'about:blank')
        DestroyDui(activeDuiObj)
        activeDuiObj = nil
        activeDuiHandle = nil
    end
end

---Cria e vincula o DUI à textura de tempo de execução
local function InitializeDuiInstance()
    if activeDuiObj then return end

    local cfg = Config.General.NewsroomDisplay or {}
    local encodedUrl = ('https://cfx-nui-%s/web/newsroom_live.html'):format(GetCurrentResourceName())
    local res = cfg.duiResolution or { width = 1024, height = 576 }

    activeDuiObj = CreateDui(encodedUrl, res.width, res.height)
    activeDuiHandle = GetDuiHandle(activeDuiObj)

    if not runtimeTxdCreated then
        local txd = CreateRuntimeTxd(txdName)
        CreateRuntimeTextureFromDuiHandle(txd, txnName, activeDuiHandle)
        runtimeTxdCreated = true
    end

    -- Envia dados atuais assim que a página carregar
    SetTimeout(1200, function()
        if activeDuiObj then
            PushDataToDui(currentDisplayData)
        end
    end)
end

---Inicializa o ponto de streaming do monitor da redação
local function SetupNewsroomDisplay()
    local cfg = Config.General.NewsroomDisplay
    if not cfg or cfg.enabled == false then return end

    local screenCoords = cfg.coords or vector3(-578.5, -934.0, 25.5)
    local streamDist = cfg.streamDistance or 22.0
    local drawDist = cfg.drawDistance or 18.0
    local width = cfg.width or 2.4
    local height = cfg.height or 1.35
    local heading = cfg.heading or 270.0

    newsroomPoint = lib.points.new({
        coords = screenCoords,
        distance = streamDist,
    })

    function newsroomPoint:onEnter()
        self.active = true
        InitializeDuiInstance()

        -- Loop de renderização 3D contínua otimizado (0.00ms idle, resmon consciente)
        CreateThread(function()
            while self.active do
                local ped = PlayerPedId()
                local pedCoords = GetEntityCoords(ped)
                local dist = #(pedCoords - screenCoords)
                if dist <= drawDist then
                    DrawScreenQuad(screenCoords, heading, width, height, txdName, txnName)
                    Wait(0)
                else
                    Wait(250)
                end
            end
        end)
    end

    function newsroomPoint:onExit()
        self.active = false
        CleanupDui()
    end
end

-- ==========================================================
-- Sincronização de Manchetes e Plantões no Monitor
-- ==========================================================

local breakingNewsTimer = 0

---Quando um plantão urgente é transmitido
RegisterNetEvent('vp_newspaper:client:displayBreakingNews', function(headline, subtitle, durationMs)
    currentDisplayData.title = headline
    currentDisplayData.subtitle = subtitle
    currentDisplayData.category = '🔴 PLANTÃO URGENTE AO VIVO'
    currentDisplayData.isBreaking = true
    currentDisplayData.tickerText = ('+++ ATENÇÃO: %s +++ %s +++ COBERTURA ESPECIAL WEAZEL NEWS +++'):format(
        headline:upper(),
        subtitle:upper()
    )

    PushDataToDui(currentDisplayData)

    local thisTimer = GetGameTimer() + (durationMs or 15000)
    breakingNewsTimer = thisTimer

    SetTimeout(durationMs or 15000, function()
        -- Prevenção de condição de corrida se houver múltiplos plantões em sequência
        if GetGameTimer() >= breakingNewsTimer then
            currentDisplayData.isBreaking = false
            currentDisplayData.category = 'ÚLTIMA HORA'
            currentDisplayData.tickerText = '+++ WEAZEL NEWS 98.5 FM NO AR +++ COBERTURA COMPLETA DE SAN ANDREAS +++'
            PushDataToDui(currentDisplayData)
        end
    end)
end)

---Atualização manual ou programática do monitor
RegisterNetEvent('vp_newspaper:client:updateNewsroomData', function(newData)
    if type(newData) ~= 'table' then return end
    for k, v in pairs(newData) do
        currentDisplayData[k] = v
    end
    PushDataToDui(currentDisplayData)
end)

-- Inicialização com atraso seguro
CreateThread(function()
    Wait(1500)
    SetupNewsroomDisplay()
end)

-- Limpeza absoluta ao parar o recurso
AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    CleanupDui()
    if newsroomPoint then
        newsroomPoint.active = false
        newsroomPoint:remove()
        newsroomPoint = nil
    end
end)

---Export para atualizar o monitor da redação
exports('UpdateNewsroomScreen', function(data)
    TriggerEvent('vp_newspaper:client:updateNewsroomData', data)
end)
