-- ============================================================================
-- vp_newspaper: Jornalismo de Campo & Pautas de Notícia (Server)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local spotCooldowns = {}

local function IsReporter(player)
    if not player then return false end
    if Config.General.allowTestCommands then return true end
    local job = player.PlayerData.job
    return job and job.name == (Config.General.jobName or 'reporter')
end

-- ============================================================================
-- Callback: Conclusão de Spot de Reportagem (Entrevista / Gravação)
-- ============================================================================
lib.callback.register('vp_newspaper:server:completeFieldSpot', function(source, spotId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return { success = false, message = 'Jogador inválido' } end

    if not IsReporter(player) then
        return { success = false, message = 'Você precisa ser repórter da Weazel News para cobrir pautas de campo.' }
    end

    local cfg = Config.General.FieldJournalism
    local spot = nil
    for _, s in ipairs(cfg.spots) do
        if s.id == spotId then
            spot = s
            break
        end
    end

    if not spot then
        return { success = false, message = 'Local de pauta não reconhecido.' }
    end

    -- Validação física de proximidade server-side
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local dist = #(pCoords - spot.coords)
    if dist > 15.0 then
        return { success = false, message = 'Você está muito distante do local da entrevista.' }
    end

    -- Validação de Cooldown
    local citizenid = player.PlayerData.citizenid
    local key = citizenid .. ':' .. spotId
    local now = os.time()
    if spotCooldowns[key] and (now - spotCooldowns[key]) < (cfg.cooldownSeconds or 180) then
        local rem = (cfg.cooldownSeconds or 180) - (now - spotCooldowns[key])
        return { success = false, message = ('Pauta em resfriamento. Aguarde %d segundos.'):format(rem) }
    end

    -- Sorteio de Aceitação de Entrevista
    local roll = math.random(1, 100) / 100.0
    if roll > (cfg.acceptChance or 0.85) then
        spotCooldowns[key] = now
        return { success = false, message = 'A testemunha/fonte recusou-se a dar entrevista neste momento.' }
    end

    spotCooldowns[key] = now

    -- Cálculo de Recompensa
    local rMin = cfg.rewardRange[1] or 150
    local rMax = cfg.rewardRange[2] or 300
    local reward = math.random(rMin, rMax)
    player.Functions.AddMoney('cash', reward, 'field-journalism-reward')

    -- Geração e Persistência da Pauta (vp_leads)
    local leadId = 'LEAD-' .. os.time() .. '-' .. math.random(1000, 9999)
    local authorName = (player.PlayerData.charinfo.firstname or 'Repórter') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
    local notes = ('Reportagem de campo registrada em: %s (%s)'):format(spot.name, spot.type)

    MySQL.insert('INSERT INTO vp_leads (lead_id, citizenid, author_name, spot_type, headline_seed, notes, used) VALUES (?, ?, ?, ?, ?, ?, 0)', {
        leadId,
        citizenid,
        authorName,
        spot.type,
        spot.headlineSeed,
        notes,
    })

    return {
        success = true,
        leadId = leadId,
        headline = spot.headlineSeed,
        reward = reward,
    }
end)

-- ============================================================================
-- Callback: Obter Pautas Ativas do Repórter
-- ============================================================================
lib.callback.register('vp_newspaper:server:getPlayerLeads', function(source)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return {} end

    local citizenid = player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT lead_id, spot_type, headline_seed, notes, created_at FROM vp_leads WHERE citizenid = ? AND used = 0 ORDER BY created_at DESC', { citizenid })
    return rows or {}
end)

-- ============================================================================
-- Callback: Consumir Pauta ao Publicar Matéria
-- ============================================================================
lib.callback.register('vp_newspaper:server:useLeadInArticle', function(source, leadId)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end

    local citizenid = player.PlayerData.citizenid
    local affected = MySQL.update.await('UPDATE vp_leads SET used = 1 WHERE lead_id = ? AND citizenid = ?', { leadId, citizenid })
    return affected and affected > 0
end)

-- ============================================================================
-- Event: Vincular Pauta a uma Edição Impressa com Bonificação
-- ============================================================================
RegisterNetEvent('vp_newspaper:server:attachLeadToPage', function(leadId, pageNum)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    local citizenid = player.PlayerData.citizenid
    local lead = MySQL.single.await('SELECT * FROM vp_leads WHERE lead_id = ? AND citizenid = ? AND used = 0', { leadId, citizenid })
    if not lead then
        TriggerClientEvent('vp_newspaper:client:notify', src, 'Pauta não encontrada ou já utilizada.', 'error')
        return
    end

    MySQL.update.await('UPDATE vp_leads SET used = 1 WHERE lead_id = ?', { leadId })
    player.Functions.AddMoney('cash', 200, 'lead-investigation-bonus')
    TriggerClientEvent('vp_newspaper:client:notify', src, ('Pauta investigativa "%s" vinculada à página %d! Bônus de $200 recebido.'):format(lead.headline_seed, pageNum or 1), 'success')
end)

