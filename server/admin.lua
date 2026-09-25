-- ==========================================================
-- vp_newspaper: Staff & Admin Diagnostic Testing Suite
-- Exclusivo para Staff / Administradores testarem o recurso
-- ==========================================================

local QBCore = nil
if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

---Verifica se o jogador possui permissões administrativas
---@param src number
---@return boolean
local function IsStaff(src)
    if not src or src == 0 then return true end

    -- Modo de Teste ou Debug ativado nas configurações permite testes sem restrição
    if Config.General and (Config.General.debugs or Config.General.allowTestCommands) then
        return true
    end

    if IsPlayerAceAllowed(tostring(src), 'command')
       or IsPlayerAceAllowed(tostring(src), 'group.admin')
       or IsPlayerAceAllowed(tostring(src), 'group.god')
       or IsPlayerAceAllowed(tostring(src), 'group.mod')
       or IsPlayerAceAllowed(tostring(src), 'vp_newspaper.admin') then
        return true
    end

    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god') then
            return true
        end
    end

    if GetResourceState('qbx_core') == 'started' and exports.qbx_core and exports.qbx_core.HasPermission then
        if exports.qbx_core:HasPermission(src, 'admin') or exports.qbx_core:HasPermission(src, 'god') then
            return true
        end
    end

    -- Se o jogador já possui o cargo de repórter / chefe Weazel News
    local player = GetPlayer(src)
    if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == (Config.General.jobName or 'reporter') then
        return true
    end

    return false
end

-- 1. Verificação de Permissão Staff
lib.callback.register('vp_newspaper:server:adminCheck', function(source)
    return IsStaff(source)
end)

-- 2. Concessão de Kits de Teste
lib.callback.register('vp_newspaper:server:adminGiveKit', function(source, kitType)
    local src = source
    if not IsStaff(src) then return false, 'Sem permissão' end

    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    local function Add(item, count, meta)
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            return exports.ox_inventory:AddItem(src, item, count, meta)
        elseif QBCore then
            return player.Functions.AddItem(item, count, nil, meta)
        end
        return false
    end

    local function Remove(item, count)
        if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
            return exports.ox_inventory:RemoveItem(src, item, count)
        elseif QBCore then
            return player.Functions.RemoveItem(item, count)
        end
        return false
    end

    if kitType == 'full' then
        Add('newspaper', 1, { serial = 'STAFF-TEST-' .. math.random(1000, 9999), edition = 1 })
        Add('newspaperbox', 1)
        Add('empty_newspaper', 5)
        Add('radio_portable', 1)
        Add('headphones', 1)
        Add('news_camera', 1)
        Add('news_mic', 1)
        return true, 'Kit completo de imprensa entregue!'

    elseif kitType == 'radio' then
        Add('radio_portable', 1)
        return true, 'Caixa de som portátil entregue!'

    elseif kitType == 'headphones' then
        Add('headphones', 1)
        return true, 'Fones de ouvido entregues!'

    elseif kitType == 'newspaper' then
        Add('newspaper', 1, { serial = 'STAFF-TEST-' .. math.random(1000, 9999), edition = 1 })
        return true, 'Exemplar de jornal impresso entregue!'

    elseif kitType == 'box' then
        Add('newspaperbox', 1)
        return true, 'Caixa de jornais para distribuição entregue!'

    elseif kitType == 'paper' then
        Add('empty_newspaper', 5)
        return true, '5 folhas de papel de jornal entregues!'

    elseif kitType == 'clear' then
        Remove('newspaper', 10)
        Remove('newspaperbox', 5)
        Remove('empty_newspaper', 50)
        Remove('radio_portable', 5)
        Remove('headphones', 5)
        Remove('news_camera', 2)
        Remove('news_mic', 2)
        return true, 'Itens de teste removidos do inventário!'
    end

    return false, 'Tipo de kit desconhecido'
end)

-- 3. Definição Rápida de Emprego / Cargo
lib.callback.register('vp_newspaper:server:adminSetJob', function(source, jobType, explicitGrade)
    local src = source
    if not IsStaff(src) then return false, 'Sem permissão' end

    local player = GetPlayer(src)
    if not player then return false, 'Jogador não encontrado' end

    local targetJob = 'unemployed'
    local targetGrade = 0

    if jobType == 'boss' then
        targetJob = Config.General.jobName or 'reporter'
        targetGrade = tonumber(explicitGrade) or Config.General.jobBossGrade or 4
    elseif jobType == 'reporter' then
        targetJob = Config.General.jobName or 'reporter'
        targetGrade = tonumber(explicitGrade) or 1
    elseif jobType == 'unemployed' then
        targetJob = 'unemployed'
        targetGrade = 0
    end

    if GetResourceState('qbx_core') == 'started' then
        local success, err = exports.qbx_core:SetJob(src, targetJob, targetGrade)
        if not success and targetJob ~= 'unemployed' then
            -- Fallback defensivo para grau 3 ou 1 caso o grau solicitado não esteja configurado
            success, err = exports.qbx_core:SetJob(src, targetJob, 3)
            if not success then
                exports.qbx_core:SetJob(src, targetJob, 0)
            end
        end
    elseif player.Functions and player.Functions.SetJob then
        player.Functions.SetJob(targetJob, targetGrade)
    end

    return true, ('Cargo alterado para: %s (Grau %d)'):format(targetJob, targetGrade)
end)

-- 4. Ações Econômicas e de Bancas
lib.callback.register('vp_newspaper:server:adminCompanyAction', function(source, action, payload)
    local src = source
    if not IsStaff(src) then return false, 'Sem permissão' end

    if action == 'add_money' then
        local amount = tonumber(payload) or 5000
        local updated = MySQL.update.await('UPDATE `vp_newspaper_company` SET `balance` = `balance` + ? WHERE `id` = 1', { amount })
        if updated and updated > 0 then
            return true, ('Injetado $%s no cofre corporativo da Weazel News!'):format(amount)
        end
        return false, 'Falha ao atualizar saldo no banco'

    elseif action == 'restock_all' then
        local updated = MySQL.update.await('UPDATE `newspaper_boxes` SET `stock` = `max_stock`', {})
        TriggerClientEvent('vp_newspaper:client:requestBoxesSync', -1)
        return true, 'Todas as bancas do mapa foram reabastecidas com estoque máximo!'

    elseif action == 'empty_nearest' and payload then
        local boxId = tonumber(payload)
        if boxId then
            MySQL.update.await('UPDATE `newspaper_boxes` SET `stock` = 0 WHERE `id` = ?', { boxId })
            TriggerClientEvent('vp_newspaper:client:requestBoxesSync', -1)
            return true, ('Estoque da banca #%d zerado para testes!'):format(boxId)
        end
        return false, 'ID de banca inválido'
    end

    return false, 'Ação desconhecida'
end)

-- 5. Ações de Rádio e Caixas de Som 3D
lib.callback.register('vp_newspaper:server:adminRadioAction', function(source, action, payload)
    local src = source
    if not IsStaff(src) then return false, 'Sem permissão' end

    if action == 'play_test_track' then
        TriggerEvent('vp_newspaper:server:addRadioTrackDirect', 'https://icecast.skyrock.net/s/natio_mp3_128k', 'Weazel News 98.5 FM — Transmissão Teste Staff', src)
        return true, 'Transmissão teste iniciada na Weazel Radio 98.5 FM!'

    elseif action == 'play_test_playlist' then
        -- Injeta playlist oficial do YouTube para validação de reprodução sequencial
        local playlistUrl = 'https://www.youtube.com/playlist?list=PL4fGSIFgk5n0JbYF2_XF9nQ4w1vL8Pj5b'
        TriggerEvent('vp_newspaper:server:addRadioTrackDirect', playlistUrl, 'Playlist Teste do YouTube (Automática)', src)
        return true, 'Playlist teste do YouTube inserida na programação!'

    elseif action == 'breaking_news' then
        TriggerEvent('vp_newspaper:server:broadcastBreakingNews', 'TESTE DE PLANTÃO STAFF', 'Transmissão de homologação da Weazel News.')
        return true, 'Alerta de Plantão Urgente emitido! Rádio atenuada em 85%.'

    elseif action == 'clear_ground_speakers' then
        TriggerClientEvent('vp_newspaper:client:syncGroundSpeakers', -1, {})
        return true, 'Todas as caixas de som no chão foram limpas!'
    end

    return false, 'Ação de rádio desconhecida'
end)

-- 6. Encontrar Banca Mais Próxima
lib.callback.register('vp_newspaper:server:adminGetNearestBox', function(source, coords)
    if not coords then return nil end
    local rows = MySQL.query.await('SELECT `id`, `coords`, `stock`, `max_stock` FROM `newspaper_boxes`', {})
    if not rows or #rows == 0 then return nil end

    local pCoords = vector3(coords.x, coords.y, coords.z)
    local closestBox = nil
    local closestDist = 999999.0

    for _, row in ipairs(rows) do
        local c = json.decode(row.coords)
        if c then
            local bCoords = vector3(c.x, c.y, c.z)
            local dist = #(pCoords - bCoords)
            if dist < closestDist then
                closestDist = dist
                closestBox = {
                    id = row.id,
                    coords = bCoords,
                    dist = dist,
                    stock = row.stock,
                    maxStock = row.max_stock
                }
            end
        end
    end

    return closestBox
end)

-- 7. Diagnóstico Completo do Sistema
lib.callback.register('vp_newspaper:server:adminGetDiagnostics', function(source)
    local src = source
    if not IsStaff(src) then return nil end

    local companyRow = MySQL.single.await('SELECT `balance` FROM `vp_newspaper_company` WHERE `id` = 1', {})
    local boxesCount = MySQL.scalar.await('SELECT COUNT(*) FROM `newspaper_boxes`', {}) or 0
    local ledgerCount = MySQL.scalar.await('SELECT COUNT(*) FROM `vp_newspaper_ledger`', {}) or 0

    return {
        version = '2.0.0 (Absorbed Rahe Speakers & Senora Signalworks)',
        framework = GetResourceState('qbx_core') == 'started' and 'QBox (qbx_core)' or 'QBCore',
        companyBalance = companyRow and companyRow.balance or 0,
        totalBoxes = boxesCount,
        ledgerEntries = ledgerCount,
        radioPlaying = StationState and StationState.isPlaying or false,
        currentTrack = (StationState and StationState.currentTrack) and StationState.currentTrack.title or 'Nenhuma',
        queueCount = StationState and #StationState.queue or 0,
        activeGroundSpeakers = ActiveGroundSpeakers and #ActiveGroundSpeakers or 0,
    }
end)

-- Exportação de helper direto para inserção de faixa de teste na rádio
AddEventHandler('vp_newspaper:server:addRadioTrackDirect', function(url, title, src)
    if StationState then
        table.insert(StationState.queue, 1, {
            title = title or 'Faixa Teste Staff',
            url = url,
            duration = 300,
            addedBy = src and GetPlayerName(src) or 'Staff'
        })
        StationState.currentTrack = table.remove(StationState.queue, 1)
        StationState.isPlaying = true
        StationState.trackStartedAt = os.time()
        TriggerClientEvent('vp_newspaper:client:syncRadioState', -1, {
            name = StationState.name,
            frequency = StationState.frequency,
            isPlaying = StationState.isPlaying,
            currentTrack = StationState.currentTrack,
            elapsed = 0,
            queueCount = #StationState.queue,
            queue = StationState.queue
        })
    end
end)

-- ==========================================================
-- Comandos Diretos de Emprego & Suporte In-Game e Console
-- ==========================================================

---Seta o jogador como Chefe ou Repórter da Weazel News
RegisterCommand('setweazel', function(source, args)
    local src = source
    local targetSrc = src
    local grade = Config.General.jobBossGrade or 4

    if src == 0 then
        -- Executado no console do servidor: setweazel <id> [grau]
        targetSrc = tonumber(args[1])
        grade = tonumber(args[2]) or (Config.General.jobBossGrade or 4)
        if not targetSrc then
            print('^1[vp_newspaper] Uso no console: setweazel <player_id> [grau]^7')
            return
        end
    else
        if not IsStaff(src) then
            NotifyPlayer(src, 'Sem permissão para usar este comando.', 'error')
            return
        end
        if args[1] and tonumber(args[1]) then
            grade = tonumber(args[1])
        end
    end

    local jobName = Config.General.jobName or 'reporter'
    if GetResourceState('qbx_core') == 'started' then
        local success, err = exports.qbx_core:SetJob(targetSrc, jobName, grade)
        if not success then
            success, err = exports.qbx_core:SetJob(targetSrc, jobName, 3)
            if not success then
                exports.qbx_core:SetJob(targetSrc, jobName, 0)
            end
        end
    else
        local player = GetPlayer(targetSrc)
        if player and player.Functions and player.Functions.SetJob then
            player.Functions.SetJob(jobName, grade)
        end
    end

    if src ~= 0 then
        NotifyPlayer(src, ('Você foi setado como %s (Grau %d)!'):format(jobName, grade), 'success')
    else
        print(('^2[vp_newspaper] Sucesso: Jogador ID %d setado como %s (Grau %d)!^7'):format(targetSrc, jobName, grade))
    end
end, false)

RegisterCommand('seteweazel', function(source, args)
    ExecuteCommand(('setweazel %s'):format(args[1] or '4'))
end, false)

RegisterCommand('setreporter', function(source, args)
    ExecuteCommand(('setweazel %s'):format(args[1] or '4'))
end, false)

---Reseta o jogador para desempregado
RegisterCommand('tirarweazel', function(source)
    local src = source
    if src == 0 then return end
    if not IsStaff(src) then
        NotifyPlayer(src, 'Sem permissão para usar este comando.', 'error')
        return
    end

    if GetResourceState('qbx_core') == 'started' then
        exports.qbx_core:SetJob(src, 'unemployed', 0)
    else
        local player = GetPlayer(src)
        if player and player.Functions and player.Functions.SetJob then
            player.Functions.SetJob('unemployed', 0)
        end
    end

    NotifyPlayer(src, 'Emprego removido. Você agora é desempregado.', 'info')
end, false)
