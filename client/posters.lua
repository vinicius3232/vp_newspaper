-- ==========================================================
-- vp_newspaper: Posters Module (DUI Wall Rendering & Raycasting)
-- ==========================================================

local ActivePosters = {}
local PosterPoints = {}
local isPlacingPoster = false

---Calcula a direção da câmera em 3D
---@return vector3
local function GetCameraDirection()
    local rot = GetGameplayCamRot(2)
    local rotZ = math.rad(rot.z)
    local rotX = math.rad(rot.x)
    local multXY = math.abs(math.cos(rotX))
    return vector3(-math.sin(rotZ) * multXY, math.cos(rotZ) * multXY, math.sin(rotX))
end

---Realiza raycast da câmera para detectar superfícies verticais (paredes)
---@param maxDist number
---@return boolean hit, vector3 endCoords, vector3 surfaceNormal, number entityHit
local function RaycastWallFromCamera(maxDist)
    local camCoords = GetGameplayCamCoord()
    local camDir = GetCameraDirection()
    local targetCoords = camCoords + (camDir * maxDist)

    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        targetCoords.x, targetCoords.y, targetCoords.z,
        1 | 16, -- World geometry & Objects
        PlayerPedId(),
        0
    )
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
    return hit == 1, endCoords, surfaceNormal, entityHit
end

---Renderiza um quad de poster 3D na parede utilizando DrawSpritePoly
---@param coords vector3
---@param heading number
---@param width number
---@param height number
---@param txd string
---@param txn string
local function DrawPosterQuad(coords, heading, width, height, txd, txn)
    local rad = math.rad(heading)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0) * (width * 0.5)
    local up = vector3(0.0, 0.0, 1.0) * (height * 0.5)

    local TL = coords - right + up
    local TR = coords + right + up
    local BL = coords - right - up
    local BR = coords + right - up

    -- Triângulo superior-esquerdo
    DrawSpritePoly(
        TL.x, TL.y, TL.z,
        TR.x, TR.y, TR.z,
        BL.x, BL.y, BL.z,
        255, 255, 255, 255,
        txd, txn,
        0.0, 0.0, 1.0,
        1.0, 0.0, 1.0,
        0.0, 1.0, 1.0
    )

    -- Triângulo inferior-direito
    DrawSpritePoly(
        TR.x, TR.y, TR.z,
        BR.x, BR.y, BR.z,
        BL.x, BL.y, BL.z,
        255, 255, 255, 255,
        txd, txn,
        1.0, 0.0, 1.0,
        1.0, 1.0, 1.0,
        0.0, 1.0, 1.0
    )
end

---Desenha um quad colorido translúcido para pré-visualização da área na parede
local function DrawPreviewQuad(coords, heading, width, height, r, g, b, a)
    local rad = math.rad(heading)
    local right = vector3(math.cos(rad), math.sin(rad), 0.0) * (width * 0.5)
    local up = vector3(0.0, 0.0, 1.0) * (height * 0.5)

    local TL = coords - right + up
    local TR = coords + right + up
    local BL = coords - right - up
    local BR = coords + right - up

    DrawPoly(TL.x, TL.y, TL.z, TR.x, TR.y, TR.z, BL.x, BL.y, BL.z, r, g, b, a)
    DrawPoly(TR.x, TR.y, TR.z, BR.x, BR.y, BR.z, BL.x, BL.y, BL.z, r, g, b, a)
    DrawPoly(BL.x, BL.y, BL.z, TR.x, TR.y, TR.z, TL.x, TL.y, TL.z, r, g, b, a)
    DrawPoly(BL.x, BL.y, BL.z, BR.x, BR.y, BR.z, TR.x, TR.y, TR.z, r, g, b, a)
end

-- ==========================================================
-- Streaming de DUI Inteligente via lib.points (Anti-Leak)
-- ==========================================================

local function ClearAllPosterPoints()
    for _, pt in pairs(PosterPoints) do
        if pt.duiObj then
            SetDuiUrl(pt.duiObj, 'about:blank')
            DestroyDui(pt.duiObj)
            pt.duiObj = nil
        end
        pt.active = false
        pt:remove()
    end
    PosterPoints = {}
end

local function RegisterPosterPoint(poster)
    if PosterPoints[poster.id] then return end

    local conf = Config.General.Posters or {}
    local streamDist = conf.streamDistance or 18.0
    local drawDist = conf.drawDistance or 15.0

    local pt = lib.points.new({
        coords = poster.coords,
        distance = streamDist,
        posterId = poster.id,
        posterData = poster
    })

    function pt:onEnter()
        local txdName = ('vp_post_%s'):format(self.posterId)
        local txnName = 'poster_img'
        local encodedUrl = ('https://cfx-nui-%s/web/poster_dui.html?url=%s'):format(
            GetCurrentResourceName(),
            self.posterData.url
        )

        local duiObj = CreateDui(encodedUrl, 512, 512)
        local duiHandle = GetDuiHandle(duiObj)
        local txd = CreateRuntimeTxd(txdName)
        CreateRuntimeTextureFromDuiHandle(txd, txnName, duiHandle)

        self.duiObj = duiObj
        self.txdName = txdName
        self.txnName = txnName
        self.active = true

        -- Loop de desenho contínuo enquanto na proximidade
        CreateThread(function()
            while self.active do
                local pedCoords = GetEntityCoords(PlayerPedId())
                local dist = #(pedCoords - self.coords)
                if dist <= drawDist then
                    DrawPosterQuad(
                        self.coords,
                        self.posterData.heading,
                        self.posterData.width or 0.7,
                        self.posterData.height or 1.0,
                        self.txdName,
                        self.txnName
                    )
                    Wait(0)
                else
                    Wait(300)
                end
            end
        end)
    end

    function pt:onExit()
        self.active = false
        if self.duiObj then
            SetDuiUrl(self.duiObj, 'about:blank')
            DestroyDui(self.duiObj)
            self.duiObj = nil
        end
    end

    PosterPoints[poster.id] = pt
end

-- ==========================================================
-- Sincronização vinda do Servidor
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:syncPosters', function(posters)
    ClearAllPosterPoints()
    ActivePosters = posters or {}
    for _, p in pairs(ActivePosters) do
        RegisterPosterPoint(p)
    end
end)

RegisterNetEvent('vp_newspaper:client:addPoster', function(newPoster)
    if not newPoster or not newPoster.id then return end
    ActivePosters[newPoster.id] = newPoster
    RegisterPosterPoint(newPoster)
end)

RegisterNetEvent('vp_newspaper:client:removePoster', function(posterId)
    posterId = tonumber(posterId)
    ActivePosters[posterId] = nil
    if PosterPoints[posterId] then
        if PosterPoints[posterId].duiObj then
            SetDuiUrl(PosterPoints[posterId].duiObj, 'about:blank')
            DestroyDui(PosterPoints[posterId].duiObj)
        end
        PosterPoints[posterId].active = false
        PosterPoints[posterId]:remove()
        PosterPoints[posterId] = nil
    end
end)

CreateThread(function()
    Wait(2500)
    TriggerServerEvent('vp_newspaper:server:requestPosters')
end)

-- ==========================================================
-- Modo de Posicionamento Interativo com Raycast
-- ==========================================================

local function StartPosterPlacement()
    if isPlacingPoster then return end
    isPlacingPoster = true

    local selectedScale = 2 -- 1: Pequeno (0.5x0.7), 2: Médio (0.7x1.0), 3: Grande (1.0x1.4)
    local scales = {
        { width = 0.5, height = 0.7, label = 'Pequeno' },
        { width = 0.7, height = 1.0, label = 'Médio' },
        { width = 1.0, height = 1.4, label = 'Grande' },
    }

    lib.showTextUI('[E] Fixar Cartaz | [Q/E] Alterar Tamanho | [BACKSPACE] Cancelar', {
        icon = 'fas fa-newspaper',
        position = 'left-center'
    })

    local chosenCoords = nil
    local chosenHeading = 0.0

    while isPlacingPoster do
        Wait(0)
        DisableControlAction(0, 38, true)  -- E
        DisableControlAction(0, 44, true)  -- Q
        DisableControlAction(0, 177, true) -- Backspace

        local hit, hitCoords, normal = RaycastWallFromCamera(3.5)

        if hit and math.abs(normal.z) < 0.4 then
            -- Parede vertical válida
            local wallHeading = (GetHeadingFromVector_2d(normal.x, normal.y) + 90.0) % 360.0
            local offsetPos = hitCoords + (normal * 0.02) -- Afastamento milimétrico anti-z-fighting

            chosenCoords = offsetPos
            chosenHeading = wallHeading

            local curScale = scales[selectedScale]
            DrawPreviewQuad(offsetPos, wallHeading, curScale.width, curScale.height, 0, 255, 120, 140)

            -- Alternar escala
            if IsDisabledControlJustPressed(0, 44) then -- Q
                selectedScale = selectedScale - 1
                if selectedScale < 1 then selectedScale = #scales end
                TriggerEvent('vp_newspaper:client:notify', 'Tamanho: ' .. scales[selectedScale].label, 'info')
            elseif IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                -- Confirmar posição e abrir formulário de URL
                isPlacingPoster = false
                lib.hideTextUI()

                local input = lib.inputDialog('Colar Cartaz na Parede', {
                    { type = 'input', label = 'Título / Manchete', description = 'Nome ou tema do cartaz', required = true, min = 3, max = 50 },
                    { type = 'input', label = 'URL da Imagem (JPG / PNG / WEBP)', description = 'Link direto da imagem', required = true }
                })

                if input and input[1] and input[2] then
                    local ped = PlayerPedId()
                    lib.requestAnimDict('anim@narcotics@trash')
                    TaskPlayAnim(ped, 'anim@narcotics@trash', 'drop_front', 2.0, -8.0, 3000, 49, 0, false, false, false)

                    local progress = lib.progressBar({
                        duration = 3000,
                        label = 'Colando cartaz na parede...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true }
                    })
                    ClearPedTasks(ped)

                    if progress then
                        TriggerServerEvent('vp_newspaper:server:createPoster', {
                            title = input[1],
                            url = input[2],
                            coords = chosenCoords,
                            heading = chosenHeading,
                            width = curScale.width,
                            height = curScale.height
                        })
                    end
                else
                    TriggerEvent('vp_newspaper:client:notify', 'Fixação do cartaz cancelada.', 'info')
                end
                break
            end
        else
            -- Superfície inadequada (chão, teto ou muito longe)
            chosenCoords = nil
        end

        -- Cancelamento via Backspace
        if IsDisabledControlJustPressed(0, 177) then
            isPlacingPoster = false
            lib.hideTextUI()
            TriggerEvent('vp_newspaper:client:notify', 'Fixação do cartaz cancelada.', 'info')
            break
        end
    end
end

RegisterNetEvent('vp_newspaper:client:startPosterPlacement', function()
    StartPosterPlacement()
end)

-- ==========================================================
-- Remoção / Rasgar Cartaz Mais Próximo
-- ==========================================================

local function RemoveClosestPoster()
    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)

    local closestId, closestDist = nil, 999.0
    for id, p in pairs(ActivePosters) do
        local dist = #(pCoords - p.coords)
        if dist < closestDist then
            closestDist = dist
            closestId = id
        end
    end

    if closestId and closestDist <= 2.5 then
        lib.requestAnimDict('mini@repair')
        TaskPlayAnim(ped, 'mini@repair', 'fixing_a_ped', 2.0, -8.0, 4000, 49, 0, false, false, false)

        local success = lib.progressBar({
            duration = 4000,
            label = 'Rasgando e removendo cartaz...',
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true }
        })
        ClearPedTasks(ped)

        if success then
            TriggerServerEvent('vp_newspaper:server:deletePoster', closestId)
        end
    else
        TriggerEvent('vp_newspaper:client:notify', 'Nenhum cartaz próximo o suficiente para rasgar (máx 2.5m).', 'error')
    end
end

RegisterNetEvent('vp_newspaper:client:removeClosestPoster', function()
    RemoveClosestPoster()
end)

-- Limpeza geral ao parar o recurso
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearAllPosterPoints()
    if isPlacingPoster then
        lib.hideTextUI()
        isPlacingPoster = false
    end
end)
