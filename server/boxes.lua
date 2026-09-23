-- ==========================================================
-- vp_newspaper: Newspaper Boxes (Dispensers), Buying & Restocking
-- ==========================================================

local Boxes = {}

---Gera serial UUID v4 para rastreabilidade de jornais
---@return string
local function GenerateSerial()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

---Carrega todas as bancas do banco de dados na inicialização
local function LoadBoxes()
    MySQL.query('SELECT * FROM `newspaper_boxes`', {}, function(results)
        if results and #results > 0 then
            Boxes = {}
            for _, row in ipairs(results) do
                local c = json.decode(row.coords)
                Boxes[row.id] = {
                    id = row.id,
                    coords = vector3(c.x, c.y, c.z),
                    heading = row.heading or 0.0,
                    stock = row.stock or 15
                }
            end
        else
            -- Seed padrão inicial
            Boxes = {}
            for i, def in ipairs(Config.General.defaultBoxes) do
                local cJson = json.encode({ x = def.coords.x, y = def.coords.y, z = def.coords.z })
                MySQL.query('INSERT INTO `newspaper_boxes` (`id`, `coords`, `heading`, `stock`) VALUES (?, ?, ?, ?)', {
                    def.id, cJson, def.coords.w, def.stock
                })
                Boxes[def.id] = {
                    id = def.id,
                    coords = vector3(def.coords.x, def.coords.y, def.coords.z),
                    heading = def.coords.w,
                    stock = def.stock
                }
            end
        end
        TriggerClientEvent('vp_newspaper:client:syncBoxes', -1, Boxes)
    end)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(1500)
    LoadBoxes()
end)

-- Sincronização ao carregar o jogador
RegisterNetEvent('vp_newspaper:server:requestBoxes', function()
    local src = source
    TriggerClientEvent('vp_newspaper:client:syncBoxes', src, Boxes)
end)

-- Callback legado compatível para buscar bancas
if QBCore then
    QBCore.Functions.CreateCallback('nproblem_newspaper_kutularial', function(source, cb)
        cb(Boxes)
    end)
end

-- ==========================================================
-- Compra de Jornal na Banca (Fail-Closed & Anti-Cheat Distance)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:buyNewspaper', function(boxId)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    local box = Boxes[boxId]
    if not box then return end

    -- Verificação de distância física (OneSync Infinity)
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - box.coords) > 4.5 then
        print(('^1[vp_newspaper] Alerta Anti-Exploit: Jogador %s tentou comprar jornal a %.2fm da banca %s!^7'):format(src, #(pCoords - box.coords), boxId))
        return
    end

    -- Verificação de estoque
    if Config.General.isBoxCheckAvailable and box.stock <= 0 then
        NotifyPlayer(src, _U('noNewspaper'), 'error')
        return
    end

    -- Obter preço atual da empresa
    GetCompanyData(function(comp)
        local price = comp.newspaperPrice or 10
        local pMoney = GetPlayerMoney(src, 'cash')
        local usedType = 'cash'

        if pMoney < price then
            pMoney = GetPlayerMoney(src, 'bank')
            usedType = 'bank'
            if pMoney < price then
                NotifyPlayer(src, _U('buyNewspaperError'), 'error')
                return
            end
        end

        -- Fail-Closed: Remove dinheiro primeiro
        if not RemovePlayerMoney(src, usedType, price, 'newspaper_purchase') then
            NotifyPlayer(src, _U('buyNewspaperError'), 'error')
            return
        end

        -- Atualiza estoque da banca
        if Config.General.isBoxCheckAvailable then
            box.stock = box.stock - 1
            MySQL.query('UPDATE `newspaper_boxes` SET `stock` = ? WHERE `id` = ?', { box.stock, boxId })
            TriggerClientEvent('vp_newspaper:client:updateBoxStock', -1, boxId, box.stock)
        end

        -- Adiciona renda à empresa
        AddCompanyRevenue(price)

        -- Adiciona item ao inventário
        local serial = GenerateSerial()
        local cid = player.PlayerData.citizenid

        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            exports.ox_inventory:AddItem(src, Config.General.newspaperItemName, 1, {
                serial = serial,
                date = os.date('%d/%m/%Y'),
                edition = 1
            })
        elseif QBCore then
            player.Functions.AddItem(Config.General.newspaperItemName, 1, false, {
                serial = serial,
                date = os.date('%d/%m/%Y'),
                edition = 1
            })
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.General.newspaperItemName], 'add')
        end

        -- Registra cópia no banco de dados para anti-dupe
        MySQL.query('INSERT IGNORE INTO `vp_newspaper_copies` (`serial`, `owner_cid`, `newspaper_id`) VALUES (?, ?, ?)', {
            serial, cid, 1
        })

        NotifyPlayer(src, _U('buyNewspaperSuccess', price), 'success')
    end)
end)

-- ==========================================================
-- Reabastecimento da Banca por Entregadores
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:restockBox', function(boxId)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    local box = Boxes[boxId]
    if not box then return end

    -- Verificação de distância
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    if #(pCoords - box.coords) > 4.5 then return end

    -- Verificação se já está cheia
    if box.stock >= Config.General.allowedBoxSpace then
        NotifyPlayer(src, _U('restockFullError'), 'error')
        return
    end

    -- Verificação do item necessário (newspaperbox)
    local hasItem = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:GetItemCount(src, Config.General.restockBoxesItemName)
        hasItem = (count and count > 0)
    elseif QBCore then
        local item = player.Functions.GetItemByName(Config.General.restockBoxesItemName)
        hasItem = (item and item.amount and item.amount > 0)
    end

    if not hasItem then
        NotifyPlayer(src, _U('restockNoItemError'), 'error')
        return
    end

    -- Fail-Closed: Remove a caixa de jornais
    local removed = false
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        removed = exports.ox_inventory:RemoveItem(src, Config.General.restockBoxesItemName, 1)
    elseif QBCore then
        removed = player.Functions.RemoveItem(Config.General.restockBoxesItemName, 1)
        if removed then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[Config.General.restockBoxesItemName], 'remove')
        end
    end

    if not removed then
        NotifyPlayer(src, _U('restockNoItemError'), 'error')
        return
    end

    -- Atualiza estoque para o máximo
    box.stock = Config.General.allowedBoxSpace
    MySQL.query('UPDATE `newspaper_boxes` SET `stock` = ? WHERE `id` = ?', { box.stock, boxId })
    TriggerClientEvent('vp_newspaper:client:updateBoxStock', -1, boxId, box.stock)

    -- Recompensa monetária
    local reward = 0
    if Config.General.restockReward then
        local minR = Config.General.restockPerReward[1] or 35
        local maxR = Config.General.restockPerReward[2] or 70
        reward = math.random(minR, maxR)
        AddPlayerMoney(src, 'cash', reward, 'newspaper_restock_delivery')
    end

    NotifyPlayer(src, _U('restockSuccess', reward), 'success')
end)

-- ==========================================================
-- Comando Staff para Criar Banca Permanente
-- ==========================================================

RegisterCommand(Config.General.creatingBoxes.command, function(source, args)
    local src = source
    if src == 0 then return end

    local player = GetPlayer(src)
    if not player then return end

    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    local cJson = json.encode({ x = coords.x, y = coords.y, z = coords.z })
    MySQL.query('INSERT INTO `newspaper_boxes` (`coords`, `heading`, `stock`) VALUES (?, ?, ?)', {
        cJson, heading, Config.General.allowedBoxSpace
    }, function(res)
        local insertId = res and (res.insertId or res)
        if insertId then
            Boxes[insertId] = {
                id = insertId,
                coords = coords,
                heading = heading,
                stock = Config.General.allowedBoxSpace
            }
            TriggerClientEvent('vp_newspaper:client:syncBoxes', -1, Boxes)
            NotifyPlayer(src, _U('boxCreated'), 'success')
        end
    end)
end, true)
