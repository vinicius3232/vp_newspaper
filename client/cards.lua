-- ============================================================================
-- vp_newspaper: Sistema de Trading Cards, Boosters & PSA Grading (Client)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================================================
-- Função: Abertura de Pacote Booster
-- ============================================================================
local function OpenBoosterPack(slot)
    local cfg = Config.General.Collectibles
    local animDict = 'mp_arresting'
    local animClip = 'a_uncuff'

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(50)
    end

    TaskPlayAnim(cache.ped, animDict, animClip, 8.0, -8.0, -1, 49, 0, false, false, false)

    local success = lib.progressBar({
        duration = cfg.grading.openingTimeMs or 3500,
        label = 'Abrindo pacote de cartas Weazel...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
    })

    ClearPedTasks(cache.ped)

    if not success then
        lib.notify({
            title = 'Colecionáveis',
            description = 'Abertura cancelada.',
            type = 'inform',
        })
        return
    end

    local res = lib.callback.await('vp_newspaper:server:openBoosterPack', false, slot)
    if not res or not res.success then
        lib.notify({
            title = 'Colecionáveis',
            description = (res and res.message) or 'Falha ao abrir o pacote.',
            type = 'error',
        })
        return
    end

    -- Apresenta as cartas reveladas
    local elements = {}
    for _, c in ipairs(res.cards) do
        local rarityConfig = cfg.rarities[c.rarity] or { label = c.rarity, color = '#ffffff' }
        table.insert(elements, ('• **%s** (%s)\n  _%s_'):format(c.title, rarityConfig.label, c.description))
    end

    lib.alertDialog({
        header = '🎉 Pacote de Cartas Aberto!',
        content = table.concat(elements, '\n\n'),
        centered = true,
        cancel = false,
    })
end

-- ============================================================================
-- Função: Exibição e Inspeção de Carta Colecionável
-- ============================================================================
local function InspectCard(item)
    local meta = item.metadata or {}
    local cfg = Config.General.Collectibles
    local rarityConfig = cfg.rarities[meta.rarity or 'basic'] or { label = 'Comum', color = '#ffffff' }

    local body = {}
    table.insert(body, ('**Título:** %s'):format(meta.title or 'Carta Weazel'))
    table.insert(body, ('**Raridade:** %s'):format(rarityConfig.label))
    if meta.description and #meta.description > 0 then
        table.insert(body, ('**História:** %s'):format(meta.description))
    end

    if meta.graded then
        table.insert(body, '\n---')
        table.insert(body, ('⭐ **Certificado PSA:** Selo Autenticado'))
        table.insert(body, ('**Nota Oficial:** `%d/10` (%s)'):format(meta.grade or 10, (meta.grade >= 9 and '✨ Gem Mint' or 'Excelente')))
        table.insert(body, ('**Serial Único:** `%s`'):format(meta.serial or 'PSA-UNKNOWN'))
        if meta.subscores then
            table.insert(body, ('**Subnotas:** Centralização: %d | Cantos: %d | Bordas: %d | Superfície: %d'):format(
                meta.subscores.centering or 10,
                meta.subscores.corners or 10,
                meta.subscores.edges or 10,
                meta.subscores.surface or 10
            ))
        end
    else
        table.insert(body, '\n_Status: Não Avaliada (Use um Estojo PSA para certificar e valorizar)_')
    end

    lib.alertDialog({
        header = ('🃏 %s'):format(meta.title or 'Carta'),
        content = table.concat(body, '\n'),
        centered = true,
        cancel = false,
    })
end

-- ============================================================================
-- Função: Uso de Estojo PSA para Avaliar uma Carta
-- ============================================================================
local function StartPsaGrading(caseSlot)
    local cfg = Config.General.Collectibles
    local cardItemName = cfg.items.card or 'card'

    -- Busca todas as cartas no inventário do jogador
    local items = exports.ox_inventory:Search('slots', cardItemName)
    if not items or #items == 0 then
        lib.notify({
            title = 'PSA Grading',
            description = 'Você não possui cartas no inventário para avaliar.',
            type = 'error',
        })
        return
    end

    local options = {}
    for _, c in ipairs(items) do
        local meta = c.metadata or {}
        if not meta.graded then
            table.insert(options, {
                title = meta.title or 'Carta Colecionável',
                description = ('Raridade: %s (Slot %d)'):format(meta.rarity or 'basic', c.slot),
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Submeter ao PSA Grading',
                        content = ('Deseja submeter **%s** para avaliação oficial?\n\nCusto do serviço: **$%d** em dinheiro.'):format(meta.title or 'esta carta', cfg.grading.cost or 100),
                        centered = true,
                        cancel = true,
                    })
                    if confirm == 'confirm' then
                        local progress = lib.progressBar({
                            duration = 4000,
                            label = 'Autenticando e lacrando carta no estojo PSA...',
                            useWhileDead = false,
                            canCancel = false,
                            disable = { move = true, car = true, combat = true },
                        })
                        if progress then
                            local res = lib.callback.await('vp_newspaper:server:gradeCardPSA', false, c.slot, caseSlot)
                            if res and res.success then
                                lib.alertDialog({
                                    header = '💎 Carta Autenticada pelo PSA!',
                                    content = ('Parabéns! Sua carta recebeu a nota **%d/10** (%s)!\n\n**Serial Oficial:** `%s`'):format(
                                        res.grade,
                                        (res.grade >= 9 and '✨ Gem Mint' or 'Certificada'),
                                        res.serial
                                    ),
                                    centered = true,
                                    cancel = false,
                                })
                            else
                                lib.notify({
                                    title = 'PSA Grading',
                                    description = (res and res.message) or 'Erro na avaliação.',
                                    type = 'error',
                                })
                            end
                        end
                    end
                end,
            })
        end
    end

    if #options == 0 then
        lib.notify({
            title = 'PSA Grading',
            description = 'Todas as suas cartas já foram avaliadas e encapsuladas.',
            type = 'inform',
        })
        return
    end

    lib.registerContext({
        id = 'vp_psa_select_card',
        title = 'Selecione uma Carta para Avaliar',
        options = options,
    })
    lib.showContext('vp_psa_select_card')
end

-- ============================================================================
-- Menu: Estante de Colecionador (/colecao)
-- ============================================================================
RegisterCommand('colecao', function()
    local cards = lib.callback.await('vp_newspaper:server:getPlayerCardShelf', false)
    if not cards or #cards == 0 then
        lib.notify({
            title = 'Estante de Coleção',
            description = 'Você ainda não possui cartas registradas na sua estante.',
            type = 'inform',
        })
        return
    end

    local options = {}
    local allCardsConfig = Config.General.Collectibles.cards
    for _, row in ipairs(cards) do
        local def = allCardsConfig[row.card_id] or { title = row.card_id }
        local desc = ('Raridade: %s'):format(row.rarity)
        if row.grade and row.grade > 0 then
            desc = desc .. (' | ⭐ PSA %d/10 (%s)'):format(row.grade, row.serial or 'N/A')
        end
        table.insert(options, {
            title = def.title or row.card_id,
            description = desc,
        })
    end

    lib.registerContext({
        id = 'vp_cards_shelf_menu',
        title = '📚 Sua Estante de Colecionáveis Weazel',
        options = options,
    })
    lib.showContext('vp_cards_shelf_menu')
end, false)

-- Exports usáveis integrados ao ox_inventory
exports('useBoosterPack', function(data, slot)
    OpenBoosterPack(slot or data.slot)
end)

exports('useCard', function(data)
    InspectCard(data)
end)

exports('usePsaCase', function(data, slot)
    StartPsaGrading(slot or data.slot)
end)
