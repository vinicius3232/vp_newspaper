-- ============================================================================
-- vp_newspaper: Entrega Paperboy com Arremesso Físico (Server)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local playerThrowCooldowns = {}

lib.callback.register('vp_newspaper:server:processPaperboyThrow', function(source, targetId, coords)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return { success = false, message = 'Jogador não encontrado' } end

    local cfg = Config.General.Paperboy
    if not cfg or not cfg.enabled then
        return { success = false, message = 'Modo Paperboy desativado no servidor.' }
    end

    local citizenid = player.PlayerData.citizenid
    local now = GetGameTimer()
    if playerThrowCooldowns[citizenid] and (now - playerThrowCooldowns[citizenid]) < (cfg.throwCooldownMs or 2500) then
        return { success = false, message = 'Aguarde o resfriamento para o próximo arremesso.' }
    end

    -- Busca o alvo configurado
    local target = nil
    for _, t in ipairs(cfg.throwTargets) do
        if t.id == targetId then
            target = t
            break
        end
    end

    if not target then
        return { success = false, message = 'Alvo de entrega inválido.' }
    end

    -- Validação de proximidade física do arremesso
    local ped = GetPlayerPed(src)
    local pCoords = GetEntityCoords(ped)
    local dist = #(pCoords - target.coords)
    if dist > (cfg.maxThrowDistance or 18.0) + 7.0 then
        return { success = false, message = 'Você está muito distante do alvo para arremessar.' }
    end

    -- Verificação de limite diário no banco de dados
    local stats = MySQL.single.await('SELECT deliveries_count, total_earned FROM vp_paperboy_stats WHERE citizenid = ? AND route_date = CURDATE()', { citizenid })
    local currentCount = stats and stats.deliveries_count or 0
    if currentCount >= (cfg.dailyLimit or 50) then
        return { success = false, message = 'Você atingiu o limite diário de entregas como Paperboy (50/50).' }
    end

    -- Validação e dedução do item de jornal
    local newspaperItem = Config.General.newspaperItemName or 'newspaper'
    local count = exports.ox_inventory:GetItemCount(src, newspaperItem)
    if not count or count < 1 then
        return { success = false, message = 'Você não possui jornais para arremessar!' }
    end

    local removed = exports.ox_inventory:RemoveItem(src, newspaperItem, 1)
    if not removed then
        return { success = false, message = 'Falha ao descontar exemplar de jornal.' }
    end

    playerThrowCooldowns[citizenid] = now

    -- Cálculo de Recompensa
    local rMin = cfg.rewardPerThrow[1] or 45
    local rMax = cfg.rewardPerThrow[2] or 85
    local reward = math.random(rMin, rMax)
    player.Functions.AddMoney('cash', reward, 'paperboy-delivery')

    -- Atualiza estatísticas diárias
    MySQL.insert('INSERT INTO vp_paperboy_stats (citizenid, deliveries_count, total_earned, route_date) VALUES (?, 1, ?, CURDATE()) ON DUPLICATE KEY UPDATE deliveries_count = deliveries_count + 1, total_earned = total_earned + ?', {
        citizenid,
        reward,
        reward,
    })

    return {
        success = true,
        reward = reward,
        deliveredCount = currentCount + 1,
        maxDaily = cfg.dailyLimit or 50,
    }
end)
