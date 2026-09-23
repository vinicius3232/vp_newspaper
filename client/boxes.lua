-- ==========================================================
-- vp_newspaper: Newspaper Boxes (Props, Target & Stock)
-- ==========================================================

local SpawnedBoxes = {}
local BoxEntities = {}

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

---Cria ou atualiza os props das bancas no mundo
local function RefreshBoxProps()
    -- Remove props antigos
    for _, entity in pairs(BoxEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
    BoxEntities = {}

    local model = Config.General.boxPropModel
    lib.requestModel(model)

    for id, box in pairs(SpawnedBoxes) do
        -- Verifica se já existe um prop nativo no local ou cria um estático
        local obj = CreateObject(model, box.coords.x, box.coords.y, box.coords.z - 0.98, false, false, false)
        SetEntityHeading(obj, box.heading or 0.0)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        BoxEntities[id] = obj
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
-- Integração ox_target com o Modelo das Bancas
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
                onSelect = function(data)
                    local pCoords = GetEntityCoords(PlayerPedId())
                    local boxId, box = GetClosestBox(pCoords)
                    if boxId then
                        TriggerServerEvent('vp_newspaper:server:restockBox', boxId)
                    end
                end
            }
        })
    end
end)

-- Limpeza ao parar o recurso
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, entity in pairs(BoxEntities) do
        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end
end)
