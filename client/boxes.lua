-- ==========================================================
-- vp_newspaper: Newspaper Boxes (Props, Target, Stock & Creator)
-- ==========================================================

local SpawnedBoxes = {}
local BoxPoints = {}
local isCreatingBox = false
local activePreviewEntity = nil

---Limpa todos os pontos e props ativos
local function ClearBoxPoints()
    for _, pt in pairs(BoxPoints) do
        if pt.entity and DoesEntityExist(pt.entity) then
            DeleteEntity(pt.entity)
        end
        pt:remove()
    end
    BoxPoints = {}
end

---Encontra a banca mais próxima do jogador
---@param coords vector3
---@return number|nil boxId, table|nil boxData
local function GetClosestBox(coords)
    local closestId, closestDist = nil, 999.0
    for id, box in pairs(SpawnedBoxes) do
        local dist = #(coords - box.coords)
        if dist < closestDist then
            closestDist = dist
            closestId = id
        end
    end
    if closestDist <= 3.5 then
        return closestId, SpawnedBoxes[closestId]
    end
    return nil, nil
end

---Cria pontos lib.points para streaming inteligente das bancas no mundo
local function RefreshBoxProps()
    ClearBoxPoints()

    local model = Config.General.boxPropModel

    for id, box in pairs(SpawnedBoxes) do
        local pt = lib.points.new({
            coords = box.coords,
            distance = 45.0,
            boxId = id,
            boxData = box
        })

        function pt:onEnter()
            lib.requestModel(model)
            if not self.entity or not DoesEntityExist(self.entity) then
                local obj = CreateObject(model, self.coords.x, self.coords.y, self.coords.z - 0.98, false, false, false)
                SetEntityHeading(obj, self.boxData.heading or 0.0)
                FreezeEntityPosition(obj, true)
                SetEntityInvincible(obj, true)
                self.entity = obj
            end
        end

        function pt:onExit()
            if self.entity and DoesEntityExist(self.entity) then
                DeleteEntity(self.entity)
                self.entity = nil
            end
        end

        BoxPoints[id] = pt
    end
end

-- ==========================================================
-- Sincronização vinda do Servidor
-- ==========================================================

RegisterNetEvent('vp_newspaper:client:syncBoxes', function(boxes)
    SpawnedBoxes = boxes or {}
    RefreshBoxProps()
end)

RegisterNetEvent('vp_newspaper:client:updateBoxStock', function(boxId, newStock)
    if SpawnedBoxes[boxId] then
        SpawnedBoxes[boxId].stock = newStock
    end
end)

-- Solicita bancas ao iniciar
CreateThread(function()
    Wait(2000)
    TriggerServerEvent('vp_newspaper:server:requestBoxes')
end)

-- ==========================================================
-- Radar / Outline de Estoque para Entregadores Weazel News
-- ==========================================================

local activeOutlinedBoxes = {}

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()

        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            local isDelivery = (CurrentDeliveryVehicle and veh == CurrentDeliveryVehicle)
                or (veh and DoesEntityExist(veh) and Entity(veh).state.isDeliveryVehicle)

            if isDelivery then
                sleep = 400
                local pCoords = GetEntityCoords(ped)
                local currentIdsInRange = {}

                for id, pt in pairs(BoxPoints) do
                    if pt.entity and DoesEntityExist(pt.entity) then
                        local dist = #(pCoords - pt.coords)
                        if dist <= 15.0 then
                            currentIdsInRange[id] = true
                            local stock = (SpawnedBoxes[id] and SpawnedBoxes[id].stock) or 0

                            SetEntityDrawOutline(pt.entity, true)
                            if stock < 5 then
                                SetEntityDrawOutlineColor(255, 0, 0, 255) -- Vermelho: Crítico
                            elseif stock < 10 then
                                SetEntityDrawOutlineColor(255, 255, 0, 255) -- Amarelo: Médio
                            else
                                SetEntityDrawOutlineColor(0, 255, 0, 255) -- Verde: Abastecido
                            end
                            activeOutlinedBoxes[id] = pt.entity
                        end
                    end
                end

                -- Limpa outline das bancas que saíram do raio de proximidade
                for id, entity in pairs(activeOutlinedBoxes) do
                    if not currentIdsInRange[id] then
                        if DoesEntityExist(entity) then
                            SetEntityDrawOutline(entity, false)
                        end
                        activeOutlinedBoxes[id] = nil
                    end
                end
            else
                if next(activeOutlinedBoxes) then
                    for _, entity in pairs(activeOutlinedBoxes) do
                        if DoesEntityExist(entity) then
                            SetEntityDrawOutline(entity, false)
                        end
                    end
                    activeOutlinedBoxes = {}
                end
            end
        else
            if next(activeOutlinedBoxes) then
                for _, entity in pairs(activeOutlinedBoxes) do
                    if DoesEntityExist(entity) then
                        SetEntityDrawOutline(entity, false)
                    end
                end
                activeOutlinedBoxes = {}
            end
        end

        Wait(sleep)
    end
end)

-- ==========================================================
-- Integração ox_target com o Modelo das Bancas & Animação
-- ==========================================================

CreateThread(function()
    local model = Config.General.boxPropModel

    if Config.UseOxTarget and GetResourceState('ox_target') == 'started' then
        exports.ox_target:addModel(model, {
            {
                name = 'vp_newspaper_buy',
                icon = 'fas fa-newspaper',
                label = _U('buy_newspaper'),
                distance = 2.0,
                onSelect = function(data)
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local boxId, box = GetClosestBox(pCoords)
                    if boxId then
                        TriggerServerEvent('vp_newspaper:server:buyNewspaper', boxId)
                    end
                end
            },
            {
                name = 'vp_newspaper_restock',
                icon = 'fas fa-boxes-stacked',
                label = _U('restock_box'),
                distance = 2.0,
                groups = Config.General.jobName,
                onSelect = function(data)
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local boxId, box = GetClosestBox(pCoords)
                    if not boxId then return end

                    local ped = PlayerPedId()
                    local propHash = joaat('prop_cs_rolled_paper')
                    lib.requestModel(propHash)
                    lib.requestAnimDict('anim@narcotics@trash')

                    local pPos = GetEntityCoords(ped)
                    local paperProp = CreateObject(propHash, pPos.x, pPos.y, pPos.z, true, true, false)
                    AttachEntityToEntity(
                        paperProp,
                        ped,
                        GetPedBoneIndex(ped, 28422),
                        0.05, 0.0, 0.0,
                        0.0, 270.0, 0.0,
                        true, true, false, true, 1, true
                    )

                    TaskPlayAnim(ped, 'anim@narcotics@trash', 'drop_front', 2.0, -8.0, 2000, 49, 0, false, false, false)

                    local finished = lib.progressBar({
                        duration = 2000,
                        label = _U('restock_progress') or 'Abastecendo banca...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = { car = true, move = true }
                    })

                    if DoesEntityExist(paperProp) then
                        DeleteEntity(paperProp)
                    end
                    ClearPedTasks(ped)

                    if finished then
                        TriggerServerEvent('vp_newspaper:server:restockBox', boxId)
                    end
                end
            }
        })
    end
end)

-- ==========================================================
-- Criador Interativo de Bancas de Jornal (/criarBancaJornal)
-- ==========================================================

local function SetupInstructionalScaleform()
    local scaleform = RequestScaleformMovie('instructional_buttons')
    while not HasScaleformMovieLoaded(scaleform) do
        Wait(0)
    end

    PushScaleformMovieFunction(scaleform, 'CLEAR_ALL')
    PopScaleformMovieFunctionVoid()

    PushScaleformMovieFunction(scaleform, 'SET_CLEAR_SPACE')
    PushScaleformMovieFunctionParameterInt(200)
    PopScaleformMovieFunctionVoid()

    local buttons = {
        { control = 191, label = 'Confirmar' },
        { control = 177, label = 'Cancelar' },
        { control = 44,  label = 'Girar Esq' },
        { control = 38,  label = 'Girar Dir' },
        { control = 96,  label = 'Altura Z+' },
        { control = 97,  label = 'Altura Z-' },
        { control = 172, label = 'Mover Y' },
        { control = 174, label = 'Mover X' },
    }

    for i, btn in ipairs(buttons) do
        PushScaleformMovieFunction(scaleform, 'SET_DATA_SLOT')
        PushScaleformMovieFunctionParameterInt(i - 1)
        PushScaleformMovieMethodParameterButtonName(GetControlInstructionalButton(2, btn.control, true))
        BeginTextCommandScaleformString('STRING')
        AddTextComponentSubstringPlayerName(btn.label)
        EndTextCommandScaleformString()
        PopScaleformMovieFunctionVoid()
    end

    PushScaleformMovieFunction(scaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    PopScaleformMovieFunctionVoid()
    return scaleform
end

local function StartBoxPlacementMode()
    if isCreatingBox then return end
    isCreatingBox = true

    local ped = PlayerPedId()
    local pCoords = GetEntityCoords(ped)
    local pFwd = GetEntityForwardVector(ped)
    local currentPos = pCoords + (pFwd * 2.0)
    local currentHeading = GetEntityHeading(ped)

    local modelHash = Config.General.boxPropModel
    lib.requestModel(modelHash)

    activePreviewEntity = CreateObject(modelHash, currentPos.x, currentPos.y, currentPos.z - 0.98, false, false, false)
    SetEntityHeading(activePreviewEntity, currentHeading)
    SetEntityAlpha(activePreviewEntity, 180, false)
    SetEntityCollision(activePreviewEntity, false, false)

    local scaleform = SetupInstructionalScaleform()

    CreateThread(function()
        while isCreatingBox do
            Wait(0)
            DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255, 0)
            DrawMarker(28, currentPos.x, currentPos.y, currentPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 0, 255, 0, 120, false, false, 2, false, nil, nil, false)

            -- X Input
            if IsControlPressed(0, 175) then -- Right
                currentPos = vector3(currentPos.x + 0.02, currentPos.y, currentPos.z)
            elseif IsControlPressed(0, 174) then -- Left
                currentPos = vector3(currentPos.x - 0.02, currentPos.y, currentPos.z)
            end

            -- Y Input
            if IsControlPressed(0, 172) then -- Up
                currentPos = vector3(currentPos.x, currentPos.y + 0.02, currentPos.z)
            elseif IsControlPressed(0, 173) then -- Down
                currentPos = vector3(currentPos.x, currentPos.y - 0.02, currentPos.z)
            end

            -- Z Input (NumPad 7/1 ou PageUp/PageDown)
            if IsControlPressed(0, 96) or IsControlPressed(0, 10) then
                currentPos = vector3(currentPos.x, currentPos.y, currentPos.z + 0.02)
            elseif IsControlPressed(0, 97) or IsControlPressed(0, 11) then
                currentPos = vector3(currentPos.x, currentPos.y, currentPos.z - 0.02)
            end

            -- Heading Input (Q / E)
            if IsControlPressed(0, 44) then -- Q
                currentHeading = (currentHeading - 2.0) % 360.0
            elseif IsControlPressed(0, 38) then -- E
                currentHeading = (currentHeading + 2.0) % 360.0
            end

            if activePreviewEntity and DoesEntityExist(activePreviewEntity) then
                SetEntityCoords(activePreviewEntity, currentPos.x, currentPos.y, currentPos.z - 0.98, false, false, false, false)
                SetEntityHeading(activePreviewEntity, currentHeading)
            end

            -- Confirm (Enter)
            if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 18) then
                if activePreviewEntity and DoesEntityExist(activePreviewEntity) then
                    DeleteEntity(activePreviewEntity)
                    activePreviewEntity = nil
                end
                isCreatingBox = false
                SetScaleformMovieAsNoLongerNeeded(scaleform)

                TriggerServerEvent('vp_newspaper:server:createBox', {
                    x = currentPos.x,
                    y = currentPos.y,
                    z = currentPos.z
                }, currentHeading)
                break
            end

            -- Cancel (Backspace)
            if IsControlJustPressed(0, 177) then
                if activePreviewEntity and DoesEntityExist(activePreviewEntity) then
                    DeleteEntity(activePreviewEntity)
                    activePreviewEntity = nil
                end
                isCreatingBox = false
                SetScaleformMovieAsNoLongerNeeded(scaleform)
                TriggerEvent('vp_newspaper:client:notify', 'Instalação de banca cancelada.', 'info')
                break
            end
        end
    end)
end

local function ToggleBoxCreation()
    if isCreatingBox then
        isCreatingBox = false
        if activePreviewEntity and DoesEntityExist(activePreviewEntity) then
            DeleteEntity(activePreviewEntity)
            activePreviewEntity = nil
        end
        TriggerEvent('vp_newspaper:client:notify', 'Modo de criação de banca finalizado.', 'info')
    else
        StartBoxPlacementMode()
    end
end

RegisterCommand(Config.General.creatingBoxes.command or 'criarBancaJornal', ToggleBoxCreation)
RegisterCommand('createNewspaperBox', ToggleBoxCreation)
RegisterCommand('criarbancajornal', ToggleBoxCreation)

-- Limpeza ao parar o recurso ou desconectar
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    ClearBoxPoints()
    if activePreviewEntity and DoesEntityExist(activePreviewEntity) then
        DeleteEntity(activePreviewEntity)
        activePreviewEntity = nil
    end
    for _, entity in pairs(activeOutlinedBoxes) do
        if DoesEntityExist(entity) then
            SetEntityDrawOutline(entity, false)
        end
    end
end)
