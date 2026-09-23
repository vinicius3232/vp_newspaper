-- ==========================================================
-- vp_newspaper: Newspaper Engine, Editor Lock & Pages
-- ==========================================================

local isEditorActive = false
local editorActivePlayer = nil

---Recupera o conteúdo de uma página específica
---@param page string|number 'page1', 'page2' ou 1, 2
---@param cb function(data: table)
function GetNewspaperPage(page, cb)
    local pageKey = type(page) == 'string' and page or ('page' .. tostring(page))
    MySQL.query('SELECT * FROM `newspaper_texts` WHERE `page` = ? LIMIT 1', { pageKey }, function(results)
        if results and results[1] then
            cb(results)
        else
            cb({ { page = pageKey, general = '[]' } })
        end
    end)
end

-- ==========================================================
-- Abertura da Redação / Editor de Jornal
-- ==========================================================

RegisterNetEvent('nproblem_newspaper_back', function()
    local src = source
    local player = GetPlayer(src)
    if not player then return end

    -- Verificação de ocupação do computador da redação
    if isEditorActive and isEditorActive ~= src then
        NotifyPlayer(src, _U('editorMasa'), 'error')
        return
    end

    -- Trava o computador para o repórter
    isEditorActive = src
    editorActivePlayer = src

    GetNewspaperPage('page1', function(data)
        TriggerClientEvent('clen:openUI', src, data)
    end)
end)

-- Liberação da trava do editor ao fechar ou sair
RegisterNetEvent('nproblem_newspaper_isEditorActive2', function()
    local src = source
    if isEditorActive == src then
        isEditorActive = false
        editorActivePlayer = nil
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if isEditorActive == src then
        isEditorActive = false
        editorActivePlayer = nil
    end
end)

-- ==========================================================
-- Salvar e Manipular Páginas do Jornal (NUI Callbacks)
-- ==========================================================

RegisterNetEvent('clen:saveTexts', function(cbData, pageNum)
    local src = source
    if not cbData or not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    local generalJson = json.encode(cbData)

    MySQL.query('INSERT INTO `newspaper_texts` (`page`, `general`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `general` = ?', {
        pageKey, generalJson, generalJson
    }, function(affected)
        NotifyPlayer(src, _U('madeChanges'), 'success')
        local player = GetPlayer(src)
        local pName = player and (player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname) or ('ID ' .. src)
        SendDiscordLog('Edição de Jornal Atualizada', ('O repórter **%s** salvou alterações na **Página %s**.'):format(pName, tostring(pageNum)), 3066993)
    end)
end)

RegisterNetEvent('clen:removeText', function(elementId, pageNum)
    local src = source
    if not elementId or not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    MySQL.query('SELECT `general` FROM `newspaper_texts` WHERE `page` = ? LIMIT 1', { pageKey }, function(results)
        if results and results[1] then
            local elements = json.decode(results[1].general) or {}
            local updated = {}
            for _, item in ipairs(elements) do
                if tostring(item.id) ~= tostring(elementId) then
                    table.insert(updated, item)
                end
            end
            local generalJson = json.encode(updated)
            MySQL.query('UPDATE `newspaper_texts` SET `general` = ? WHERE `page` = ?', { generalJson, pageKey })
            NotifyPlayer(src, _U('madeChanges'), 'success')
        end
    end)
end)

RegisterNetEvent('clen:removeTextAll', function(pageNum)
    local src = source
    if not pageNum then return end

    local pageKey = 'page' .. tostring(pageNum)
    MySQL.query('UPDATE `newspaper_texts` SET `general` = ? WHERE `page` = ?', { '[]', pageKey }, function()
        NotifyPlayer(src, _U('madeChanges'), 'success')
    end)
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
            -- Se for o editor ativo enviamos changePage, caso contrário changePageView
            if isEditorActive == src then
                TriggerClientEvent('clen:changePage', src, data[1].general)
            else
                TriggerClientEvent('clen:changePageView', src, data[1].general)
            end
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
