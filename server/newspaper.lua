-- ==========================================================
-- vp_newspaper: Hardened Newspaper Engine, OCC & Editor Lock
-- ==========================================================

local ActiveEditorSession = nil ---@type { sessionId: string, src: number, cid: string, expiresAt: number }|nil

---Recupera o conteúdo de uma página específica com a revisão OCC
---@param page string|number 'page1', 'page2' ou 1, 2
---@param cb function(data: table)
function GetNewspaperPage(page, cb)
    local pageKey = type(page) == 'string' and page or ('page' .. tostring(page))
    MySQL.query('SELECT `page`, `general`, `revision`, `updated_by`, `updated_at` FROM `newspaper_texts` WHERE `page` = ? LIMIT 1', { pageKey }, function(results)
        if results and results[1] then
            cb(results)
        else
            cb({ { page = pageKey, general = '[]', revision = 1 } })
        end
    end)
end

-- ==========================================================
-- Abertura da Redação com Sessão TTL e Lock Atômico
-- ==========================================================

RegisterNetEvent('nproblem_newspaper_back', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: FAST)
    if not Security.CheckRateLimit(src, 'open_editor', 'FAST') then return end

    local isDebug = Config.General and (Config.General.debugs or Config.General.allowTestCommands)

    -- 2. Distância Física (Max 2.0m)
    local okDist = isDebug or Security.ValidateDistance(src, Config.General.Coords.editorCoord, 'EDITOR')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar junto ao computador da redação.', 'error')
        return
    end

    -- 3. Autorização: Apenas membros da equipe da redação
    local isAuth = isDebug or Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Apenas jornalistas da Weazel News podem redigir matérias!', 'error')
        return
    end

    local now = os.time()

    -- 4. Verificação de Sessão Ativa com TTL (Prevenção de Stale Lock)
    if not isDebug and ActiveEditorSession then
        if ActiveEditorSession.src ~= src and ActiveEditorSession.expiresAt > now then
            NotifyPlayer(src, _U('editorMasa'), 'error')
            return
        end
    end

    -- Criação de nova sessão com TTL de 90 segundos
    local newSessionId = Operations.GenerateUUID()
    ActiveEditorSession = {
        sessionId = newSessionId,
        src = src,
        cid = cid,
        expiresAt = now + 90
    }

    MySQL.query.await([[
        INSERT INTO `vp_newspaper_editor_sessions`
        (`session_id`, `owner_cid`, `source_id`, `acquired_at`, `expires_at`)
        VALUES (?, ?, ?, NOW(), NOW() + INTERVAL 90 SECOND)
        ON DUPLICATE KEY UPDATE `expires_at` = NOW() + INTERVAL 90 SECOND
    ]], { newSessionId, cid, src })

    GetNewspaperPage('page1', function(data)
        print(('^2[vp_newspaper] Enviando clen:openUI para o jogador %s com sessão %s^7'):format(src, newSessionId))
        TriggerClientEvent('clen:openUI', src, data, newSessionId)
    end)
end)

-- Heartbeat enviado pelo client para renovar o TTL do editor
RegisterNetEvent('vp_newspaper:server:editorHeartbeat', function(sessionId)
    local src = source
    if ActiveEditorSession and ActiveEditorSession.src == src and ActiveEditorSession.sessionId == sessionId then
        ActiveEditorSession.expiresAt = os.time() + 90
        MySQL.query([[
            UPDATE `vp_newspaper_editor_sessions`
            SET `expires_at` = NOW() + INTERVAL 90 SECOND
            WHERE `session_id` = ?
        ]], { sessionId })
    end
end)

-- Liberação segura da trava do editor ao fechar ou sair
RegisterNetEvent('nproblem_newspaper_isEditorActive2', function()
    local src = source
    if ActiveEditorSession and ActiveEditorSession.src == src then
        MySQL.query('DELETE FROM `vp_newspaper_editor_sessions` WHERE `session_id` = ?', { ActiveEditorSession.sessionId })
        ActiveEditorSession = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if ActiveEditorSession and ActiveEditorSession.src == src then
        MySQL.query('DELETE FROM `vp_newspaper_editor_sessions` WHERE `session_id` = ?', { ActiveEditorSession.sessionId })
        ActiveEditorSession = nil
    end
end)

-- ==========================================================
-- Salvar e Manipular Páginas com OCC (Optimistic Concurrency Control)
-- ==========================================================

RegisterNetEvent('clen:saveTexts', function(cbData, pageNum, expectedRevision)
    local src = source
    local player = GetPlayer(src)
    if not player then return end
    local cid = player.PlayerData.citizenid

    -- 1. Rate Limit (Tier: CRITICAL)
    if not Security.CheckRateLimit(src, 'save_newspaper_page', 'CRITICAL') then
        NotifyPlayer(src, 'Aguarde antes de salvar novamente.', 'error')
        return
    end

    local isDebug = Config.General and (Config.General.debugs or Config.General.allowTestCommands)

    -- 2. Distância Física
    local okDist = isDebug or Security.ValidateDistance(src, Config.General.Coords.editorCoord, 'EDITOR')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar na redação para salvar.', 'error')
        return
    end

    -- 3. Autorização
    local isAuth = isDebug or Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then
        NotifyPlayer(src, 'Não autorizado a alterar o conteúdo editorial!', 'error')
        return
    end

    -- 4. Validação de Sessão do Editor Ativa e Não Expirada
    if not ActiveEditorSession or ActiveEditorSession.src ~= src then
        NotifyPlayer(src, 'Nenhuma sessão ativa de edição vinculada.', 'error')
        return
    end

    if os.time() > ActiveEditorSession.expiresAt then
        NotifyPlayer(src, 'Sua sessão de edição expirou por inatividade.', 'error')
        return
    end

    -- 5. Validação de Página (Bounds Check)
    pageNum = tonumber(pageNum)
    local maxPages = Config.General.allowedMaxPage or 5
    if not pageNum or pageNum < 1 or pageNum > maxPages then
        NotifyPlayer(src, ('Número de página inválido (1-%d).'):format(maxPages), 'error')
        return
    end

    -- 6. Validação de Schema e Tamanho de Payload
    if type(cbData) ~= 'table' then
        NotifyPlayer(src, 'Formato de conteúdo inválido.', 'error')
        return
    end

    local generalJson = json.encode(cbData)
    if not generalJson or #generalJson > 65535 then
        NotifyPlayer(src, 'O conteúdo da página excede o limite de tamanho permitido.', 'error')
        return
    end

    local pageKey = 'page' .. tostring(pageNum)
    expectedRevision = tonumber(expectedRevision)

    -- OCC Update: só grava se a revisão bater com a carregada pelo editor
    local updateQuery = [[
        UPDATE `newspaper_texts`
        SET `general` = ?, `revision` = `revision` + 1, `updated_by` = ?
        WHERE `page` = ?
    ]]
    local params = { generalJson, cid, pageKey }

    if expectedRevision and expectedRevision > 0 then
        updateQuery = updateQuery .. ' AND `revision` = ?'
        table.insert(params, expectedRevision)
    end

    local result = MySQL.query.await(updateQuery, params)

    local newRevision = 1
    if not result or result.affectedRows == 0 then
        -- Conflito de versão ou página não encontrada
        if expectedRevision then
            NotifyPlayer(src, 'Conflito de edição! Outro repórter publicou alterações nesta página antes de você.', 'error')
            return
        else
            -- Insert inicial caso a página ainda não existisse
            MySQL.query.await('INSERT INTO `newspaper_texts` (`page`, `general`, `revision`, `updated_by`) VALUES (?, ?, 1, ?)', {
                pageKey, generalJson, cid
            })
            newRevision = 1
        end
    else
        local revRow = MySQL.single.await('SELECT `revision` FROM `newspaper_texts` WHERE `page` = ?', { pageKey })
        newRevision = revRow and revRow.revision or ((expectedRevision or 1) + 1)
    end

    -- Sincroniza a nova revisão com o editor local do cliente (fecha o ciclo OCC)
    TriggerClientEvent('clen:updateRevision', src, pageNum, newRevision)

    NotifyPlayer(src, _U('madeChanges'), 'success')
    local pName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
    SendDiscordLog('Edição de Jornal Atualizada', ('O repórter **%s** salvou alterações na **Página %s** (Rev %d).'):format(pName, tostring(pageNum), newRevision), 3066993)
end)

RegisterNetEvent('clen:removeText', function(elementId, pageNum)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if not Security.CheckRateLimit(src, 'remove_text', 'FAST') then return end

    local okDist = Security.ValidateDistance(src, Config.General.Coords.editorCoord, 'EDITOR')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar na redação para editar páginas.', 'error')
        return
    end

    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then return end

    if not ActiveEditorSession or ActiveEditorSession.src ~= src or os.time() > ActiveEditorSession.expiresAt then
        NotifyPlayer(src, 'Você não possui uma sessão ativa de edição.', 'error')
        return
    end

    if not elementId or not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    local pageRow = MySQL.single.await('SELECT `general`, `revision` FROM `newspaper_texts` WHERE `page` = ? LIMIT 1', { pageKey })
    if pageRow then
        local elements = json.decode(pageRow.general) or {}
        local updated = {}
        for _, item in ipairs(elements) do
            if tostring(item.id) ~= tostring(elementId) then
                table.insert(updated, item)
            end
        end
        local generalJson = json.encode(updated)
        local newRev = (pageRow.revision or 1) + 1
        MySQL.query.await('UPDATE `newspaper_texts` SET `general` = ?, `revision` = ? WHERE `page` = ?', { generalJson, newRev, pageKey })
        TriggerClientEvent('clen:updateRevision', src, pageNum, newRev)
        NotifyPlayer(src, _U('madeChanges'), 'success')
    end
end)

RegisterNetEvent('clen:removeTextAll', function(pageNum)
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    if not Security.CheckRateLimit(src, 'remove_text_all', 'FAST') then return end

    local okDist = Security.ValidateDistance(src, Config.General.Coords.editorCoord, 'EDITOR')
    if not okDist then
        NotifyPlayer(src, 'Você precisa estar na redação para limpar a página.', 'error')
        return
    end

    local isAuth = Security.IsAuthorized(src, Config.General.jobName, 0, true)
    if not isAuth then return end

    if not ActiveEditorSession or ActiveEditorSession.src ~= src or os.time() > ActiveEditorSession.expiresAt then
        NotifyPlayer(src, 'Você não possui uma sessão ativa de edição.', 'error')
        return
    end

    if not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    local pageRow = MySQL.single.await('SELECT `revision` FROM `newspaper_texts` WHERE `page` = ? LIMIT 1', { pageKey })
    local newRev = pageRow and ((pageRow.revision or 1) + 1) or 2
    MySQL.query.await('UPDATE `newspaper_texts` SET `general` = \'[]\', `revision` = ? WHERE `page` = ?', { newRev, pageKey })
    TriggerClientEvent('clen:updateRevision', src, pageNum, newRev)
    NotifyPlayer(src, _U('madeChanges'), 'success')
end)

-- ==========================================================
-- Navegação de Páginas (Editor & Leitor)
-- ==========================================================

RegisterNetEvent('changePage', function(pageNum)
    local src = source
    if not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    GetNewspaperPage(pageKey, function(data)
        if data and data[1] then
            if ActiveEditorSession and ActiveEditorSession.src == src then
                TriggerClientEvent('clen:changePage', src, data[1].general, data[1].revision)
            else
                TriggerClientEvent('clen:changePageView', src, data[1].general)
            end
        end
    end)
end)

RegisterNetEvent('changePageView', function(pageNum)
    local src = source
    if not pageNum then return end
    local pageKey = 'page' .. tostring(pageNum)
    GetNewspaperPage(pageKey, function(data)
        if data and data[1] then
            TriggerClientEvent('clen:changePageView', src, data[1].general)
        end
    end)
end)

-- Abertura direta do leitor
RegisterNetEvent('vp_newspaper:server:openReader', function()
    local src = source
    GetNewspaperPage('page1', function(data)
        TriggerClientEvent('clen:openUIview', src, data)
    end)
end)
