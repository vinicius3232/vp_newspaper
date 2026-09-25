-- ==========================================================
-- vp_newspaper: Poster Module (Server-Side Authority & Persistence)
-- ==========================================================

local ServerPosters = {}

---Carrega todos os cartazes ativos do banco de dados
local function LoadPosters()
    local ok, rows = pcall(function()
        return MySQL.query.await([[
            SELECT `id`, `citizenid`, `title`, `url`, `coords`, `heading`, `width`, `height`, `expires_at`
            FROM `newspaper_posters`
            WHERE `expires_at` IS NULL OR `expires_at` > NOW()
        ]], {})
    end)

    if not ok or not rows then
        return
    end

    ServerPosters = {}
    if #rows > 0 then
        for _, row in ipairs(rows) do
            local c = json.decode(row.coords)
            if c then
                ServerPosters[row.id] = {
                    id = row.id,
                    citizenid = row.citizenid,
                    title = row.title or 'Cartaz',
                    url = row.url,
                    coords = vector3(c.x, c.y, c.z),
                    heading = tonumber(row.heading) or 0.0,
                    width = tonumber(row.width) or 0.7,
                    height = tonumber(row.height) or 1.0,
                }
            end
        end
    end
    TriggerClientEvent('vp_newspaper:client:syncPosters', -1, ServerPosters)
end

RegisterNetEvent('vp_newspaper:server:migrationsComplete', function()
    LoadPosters()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        local attempts = 0
        while not DatabaseReady and attempts < 10 do
            Wait(300)
            attempts = attempts + 1
        end
        LoadPosters()
    end)
end)

RegisterNetEvent('vp_newspaper:server:requestPosters', function()
    local src = source
    TriggerClientEvent('vp_newspaper:client:syncPosters', src, ServerPosters)
end)

-- ==========================================================
-- Validação e Sanitização de URLs de Imagens
-- ==========================================================

local function IsValidImageUrl(url)
    if type(url) ~= 'string' or #url < 8 or #url > 1000 then
        return false
    end
    local lower = string.lower(url)
    if not (string.sub(lower, 1, 7) == 'http://' or string.sub(lower, 1, 8) == 'https://') then
        return false
    end
    if string.find(lower, 'javascript:') or string.find(lower, 'data:') or string.find(lower, '<script') then
        return false
    end
    return true
end

-- ==========================================================
-- Criação de Novo Poster (Transação Segura & Fail-Closed)
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:createPoster', function(data)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: ECONOMIC)
    if not Security.CheckRateLimit(src, 'create_poster', 'ECONOMIC') then
        NotifyPlayer(src, 'Aguarde alguns instantes antes de colar outro cartaz.', 'error')
        return
    end

    -- 2. Validação da Carga Útil (Payload)
    if type(data) ~= 'table' or not data.coords or not data.url then
        NotifyPlayer(src, 'Dados inválidos para fixação do cartaz.', 'error')
        return
    end

    if not IsValidImageUrl(data.url) then
        NotifyPlayer(src, 'A URL da imagem precisa ser um link HTTP ou HTTPS válido!', 'error')
        return
    end

    local x = tonumber(data.coords.x)
    local y = tonumber(data.coords.y)
    local z = tonumber(data.coords.z)
    local heading = tonumber(data.heading) or 0.0
    local width = math.max(0.3, math.min(3.0, tonumber(data.width) or Config.General.Posters.defaultWidth))
    local height = math.max(0.3, math.min(3.0, tonumber(data.height) or Config.General.Posters.defaultHeight))
    local title = tostring(data.title or 'Cartaz'):sub(1, 100)

    if not x or not y or not z then return end

    -- 3. Validação de Proximidade Física Server-Side (Máximo 3.5 metros da parede)
    local okDist = Security.ValidateDistance(src, vector3(x, y, z), 'WALL_POSTER')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar próximo da parede para colar o cartaz!', 'error')
        return
    end

    -- 4. Verificação de Limite de Posters por Jogador
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, 0, false)
    if not isReporter or not Config.General.Posters.reportersUnlimited then
        local count = 0
        for _, p in pairs(ServerPosters) do
            if p.citizenid == cid then
                count = count + 1
            end
        end
        if count >= (Config.General.Posters.maxPlayerPosters or 10) then
            NotifyPlayer(src, ('Você atingiu o limite de %d cartazes ativos na cidade!'):format(Config.General.Posters.maxPlayerPosters or 10), 'error')
            return
        end
    end

    -- 5. Consumo Fail-Closed do Item de Inventário
    local itemName = Config.General.Posters.itemName or 'poster'
    local itemRemoved = false

    if GetResourceState('ox_inventory') == 'started' then
        itemRemoved = exports.ox_inventory:RemoveItem(src, itemName, 1)
    elseif QBCore then
        local hasItem = player.Functions.GetItemByName(itemName)
        if hasItem and hasItem.amount >= 1 then
            itemRemoved = player.Functions.RemoveItem(itemName, 1)
            if itemRemoved then
                TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], 'remove')
            end
        end
    end

    if not itemRemoved and not isReporter then
        NotifyPlayer(src, 'Você não possui o item cartaz em mãos!', 'error')
        return
    end

    -- 6. Persistência em Banco de Dados
    local coordsJson = json.encode({ x = x, y = y, z = z })
    local insertId = MySQL.insert.await([[
        INSERT INTO `newspaper_posters` (`citizenid`, `title`, `url`, `coords`, `heading`, `width`, `height`)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { cid, title, data.url, coordsJson, heading, width, height })

    if insertId and insertId > 0 then
        local newPoster = {
            id = insertId,
            citizenid = cid,
            title = title,
            url = data.url,
            coords = vector3(x, y, z),
            heading = heading,
            width = width,
            height = height
        }
        ServerPosters[insertId] = newPoster

        TriggerClientEvent('vp_newspaper:client:addPoster', -1, newPoster)
        NotifyPlayer(src, 'Cartaz colado com sucesso!', 'success')
        SendDiscordLog('Novo Cartaz Colado', ('O cidadão/repórter **%s** colou o cartaz **"%s"** em `%.2f, %.2f, %.2f`.\nURL: %s'):format(GetPlayerName(src) or 'Cidadão', title, x, y, z, data.url), 3066993)
    else
        -- Compensação caso ocorra falha de inserção
        if itemRemoved then
            if GetResourceState('ox_inventory') == 'started' then
                exports.ox_inventory:AddItem(src, itemName, 1)
            elseif QBCore then
                player.Functions.AddItem(itemName, 1)
            end
        end
        NotifyPlayer(src, 'Falha ao registrar cartaz no banco de dados.', 'error')
    end
end)

-- ==========================================================
-- Remoção / Rasgar Cartaz
-- ==========================================================

RegisterNetEvent('vp_newspaper:server:deletePoster', function(posterId)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit
    if not Security.CheckRateLimit(src, 'delete_poster', 'ECONOMIC') then return end

    posterId = tonumber(posterId)
    local poster = ServerPosters[posterId]
    if not poster then
        NotifyPlayer(src, 'Cartaz não encontrado ou já removido.', 'error')
        return
    end

    -- 2. Checagem de Proximidade Física (< 3.5 metros)
    local okDist = Security.ValidateDistance(src, poster.coords, 'WALL_POSTER')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar próximo do cartaz para removê-lo.', 'error')
        return
    end

    -- 3. Autorização
    local isOwner = (poster.citizenid == cid)
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, 0, false)
    local isPolice = Security.IsAuthorized(src, 'police', 0, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')

    if not (isOwner or isReporter or (isPolice and Config.General.Posters.allowPoliceRemove) or isAdmin) then
        NotifyPlayer(src, 'Você não tem permissão para remover este cartaz!', 'error')
        return
    end

    -- 4. Exclusão no Banco de Dados
    MySQL.query.await('DELETE FROM `newspaper_posters` WHERE `id` = ?', { posterId })
    ServerPosters[posterId] = nil

    TriggerClientEvent('vp_newspaper:client:removePoster', -1, posterId)
    NotifyPlayer(src, 'Cartaz removido com sucesso!', 'info')
    SendDiscordLog('Cartaz Removido', ('O cartaz #%d ("%s") foi removido por **%s**.'):format(posterId, poster.title, GetPlayerName(src) or 'Desconhecido'), 15158332)
end)

-- ==========================================================
-- Itens Usáveis (ox_inventory & QBCore)
-- ==========================================================

CreateThread(function()
    local itemName = Config.General.Posters.itemName or 'poster'

    if GetResourceState('ox_inventory') == 'started' then
        exports.ox_inventory:registerHook('useItem', function(payload)
            if payload.item.name == itemName then
                TriggerClientEvent('vp_newspaper:client:startPosterPlacement', payload.source)
                return false -- Gerenciado pelo evento após colar
            end
        end)
    end

    if QBCore then
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            TriggerClientEvent('vp_newspaper:client:startPosterPlacement', source)
        end)
    end
end)

-- Comandos auxiliares
RegisterCommand('colarPoster', function(source)
    TriggerClientEvent('vp_newspaper:client:startPosterPlacement', source)
end, false)

RegisterCommand('removerPoster', function(source)
    TriggerClientEvent('vp_newspaper:client:removeClosestPoster', source)
end, false)
