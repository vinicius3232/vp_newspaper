-- ==========================================================
-- vp_newspaper: Media & Breaking News (Server Authority & Broadcast)
-- ==========================================================

local lastBreakingNewsTime = 0

---Emite um plantão urgente oficial para todos os jogadores do servidor
RegisterNetEvent('vp_newspaper:server:broadcastBreakingNews', function(headline, subtitle)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- 1. Autorização: Apenas membros qualificados da Weazel News ou Administradores
    local minGrade = Config.General.Media and Config.General.Media.breakingNews.minGrade or 2
    local isReporter = Security.IsAuthorized(src, Config.General.jobName, minGrade, false)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'command')

    if not isReporter and not isAdmin then
        NotifyPlayer(src, 'Você não possui credencial de imprensa suficiente para emitir um Plantão Urgente!', 'error')
        return
    end

    -- 2. Cooldown Global do Servidor (Anti-Spam)
    local now = os.time()
    local cooldown = Config.General.Media and Config.General.Media.breakingNews.cooldownSeconds or 60
    if (now - lastBreakingNewsTime) < cooldown then
        local remaining = cooldown - (now - lastBreakingNewsTime)
        NotifyPlayer(src, ('Aguarde %d segundos antes de emitir outro Plantão Urgente!'):format(remaining), 'error')
        return
    end

    -- 3. Sanitização e Validação do Texto
    if type(headline) ~= 'string' or #headline < 3 then
        NotifyPlayer(src, 'Manchete inválida para o Plantão!', 'error')
        return
    end

    headline = headline:gsub('<[^>]*>', ''):sub(1, 80)
    subtitle = (type(subtitle) == 'string' and subtitle ~= '') and subtitle:gsub('<[^>]*>', ''):sub(1, 140) or 'Weazel News — Cobertura Ao Vivo'

    lastBreakingNewsTime = now
    local duration = Config.General.Media and Config.General.Media.breakingNews.durationMs or 9000

    -- 4. Transmissão Global para Todos os Clientes
    TriggerClientEvent('vp_newspaper:client:displayBreakingNews', -1, headline, subtitle, duration)
    NotifyPlayer(src, 'Plantão Urgente transmitido em rede estadual com sucesso!', 'success')

    -- 5. Log Discord
    SendDiscordLog(
        '🚨 PLANTÃO URGENTE (BREAKING NEWS)',
        ('O repórter **%s** transmitiu um plantão urgente para toda a cidade:\n\n**%s**\n*%s*'):format(
            GetPlayerName(src) or 'Repórter',
            headline,
            subtitle
        ),
        16711680 -- Vermelho vivo
    )
end)

-- ==========================================================
-- Itens Usáveis do Kit de Reportagem (ox_inventory & QBCore)
-- ==========================================================

CreateThread(function()
    local mediaConf = Config.General.Media
    if not mediaConf or not mediaConf.items then return end

    local items = mediaConf.items

    -- Registro no QBX Core
    if GetResourceState('qbx_core') == 'started' and exports.qbx_core and exports.qbx_core.CreateUseableItem then
        for equipType, itemName in pairs(items) do
            exports.qbx_core:CreateUseableItem(itemName, function(source, item)
                TriggerClientEvent('vp_newspaper:client:toggleEquipment', source, equipType)
            end)
        end
    end

    -- Registro no ox_inventory (com itemFilter de alto desempenho)
    if GetResourceState('ox_inventory') == 'started' then
        local filter = {}
        for _, itemName in pairs(items) do
            filter[itemName] = true
        end
        exports.ox_inventory:registerHook('useItem', function(payload)
            for equipType, itemName in pairs(items) do
                if payload.item.name == itemName then
                    TriggerClientEvent('vp_newspaper:client:toggleEquipment', payload.source, equipType)
                    return false
                end
            end
        end, {
            itemFilter = filter
        })
    end

    -- Registro no QBCore legado
    if QBCore and QBCore.Functions and QBCore.Functions.CreateUseableItem then
        for equipType, itemName in pairs(items) do
            QBCore.Functions.CreateUseableItem(itemName, function(source, item)
                TriggerClientEvent('vp_newspaper:client:toggleEquipment', source, equipType)
            end)
        end
    end
end)

-- ==========================================================
-- Comandos Rápidos de Reportagem e Plantão
-- ==========================================================

RegisterCommand('cam', function(source)
    TriggerClientEvent('vp_newspaper:client:toggleEquipment', source, 'camera')
end, false)

RegisterCommand('mic', function(source)
    TriggerClientEvent('vp_newspaper:client:toggleEquipment', source, 'mic')
end, false)

RegisterCommand('bmic', function(source)
    TriggerClientEvent('vp_newspaper:client:toggleEquipment', source, 'boom')
end, false)

RegisterCommand('plantao', function(source, args, raw)
    local src = source
    if #args == 0 then
        NotifyPlayer(src, 'Uso: /plantao [Manchete] | [Subtítulo Opcional]', 'info')
        return
    end

    local text = table.concat(args, ' ')
    local headline, subtitle = text, ''
    local sepIndex = string.find(text, '|')
    if sepIndex then
        headline = text:sub(1, sepIndex - 1):match('^%s*(.-)%s*$')
        subtitle = text:sub(sepIndex + 1):match('^%s*(.-)%s*$')
    end

    TriggerEvent('vp_newspaper:server:broadcastBreakingNews', headline, subtitle)
end, false)
