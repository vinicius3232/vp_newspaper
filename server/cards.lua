-- ============================================================================
-- vp_newspaper: Sistema de Trading Cards, Boosters & PSA Grading (Server)
-- ============================================================================

local QBCore = exports['qb-core']:GetCoreObject()
local openingLocks = {}

local function GenerateCardSerial()
    local chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
    local serial = 'PSA-'
    for i = 1, 4 do
        local rand = math.random(1, #chars)
        serial = serial .. string.sub(chars, rand, rand)
    end
    serial = serial .. '-'
    for i = 1, 4 do
        local rand = math.random(1, #chars)
        serial = serial .. string.sub(chars, rand, rand)
    end
    return serial
end

local function RollCardRarity(tierWeights)
    local roll = math.random(1, 100)
    local cumulative = 0
    for rarity, weight in pairs(tierWeights) do
        cumulative = cumulative + weight
        if roll <= cumulative then
            return rarity
        end
    end
    return 'basic'
end

local function SelectCardByRarity(targetRarity)
    local pool = {}
    local allCards = Config.General.Collectibles.cards
    for id, data in pairs(allCards) do
        if data.rarity == targetRarity then
            table.insert(pool, data)
        end
    end
    if #pool == 0 then
        -- Fallback se pool vazia
        for _, data in pairs(allCards) do
            table.insert(pool, data)
        end
    end
    return pool[math.random(1, #pool)]
end

-- ============================================================================
-- Callback: Abertura de Booster Pack (Server-Authoritative)
-- ============================================================================
lib.callback.register('vp_newspaper:server:openBoosterPack', function(source, slot)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return { success = false, message = 'Jogador não encontrado' } end

    local citizenid = player.PlayerData.citizenid
    if openingLocks[citizenid] and (os.time() - openingLocks[citizenid]) < 5 then
        return { success = false, message = 'Operação em andamento. Aguarde...' }
    end
    openingLocks[citizenid] = os.time()

    local cfg = Config.General.Collectibles
    local boosterItemName = cfg.items.boosterPack or 'booster_pack'

    -- Validação do item no slot do ox_inventory
    local item = exports.ox_inventory:GetSlot(src, slot)
    if not item or item.name ~= boosterItemName or item.count < 1 then
        openingLocks[citizenid] = nil
        return { success = false, message = 'Pacote inválido ou não encontrado no inventário' }
    end

    local tier = (item.metadata and item.metadata.tier) or 'common'
    local tierConfig = cfg.boosters['booster_' .. tier] or cfg.boosters.booster_common
    local cardsCount = tierConfig.count or 3
    local weights = tierConfig.weights or { basic = 80, rare = 18, legendary = 2 }

    -- Remoção Fail-Closed antes da concessão das cartas
    local removed = exports.ox_inventory:RemoveItem(src, boosterItemName, 1, nil, slot)
    if not removed then
        openingLocks[citizenid] = nil
        return { success = false, message = 'Falha ao consumir o pacote de cartas' }
    end

    -- Sorteio de cartas
    local drawnCards = {}
    for i = 1, cardsCount do
        local rarity = RollCardRarity(weights)
        local cardData = SelectCardByRarity(rarity)
        table.insert(drawnCards, {
            id = cardData.id,
            rarity = cardData.rarity,
            title = cardData.title,
            description = cardData.description,
            image = cardData.image,
        })
    end

    -- Adiciona as cartas ao inventário com metadados
    local cardItemName = cfg.items.card or 'card'
    for _, card in ipairs(drawnCards) do
        local metadata = {
            cardId = card.id,
            rarity = card.rarity,
            title = card.title,
            description = card.description,
            image = card.image,
            graded = false,
        }
        exports.ox_inventory:AddItem(src, cardItemName, 1, metadata)

        -- Registra na estante/banco de dados
        MySQL.insert('INSERT INTO vp_cards_shelf (citizenid, card_id, rarity, serial, grade) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE card_id = card_id', {
            citizenid,
            card.id,
            card.rarity,
            nil,
            0,
        })
    end

    openingLocks[citizenid] = nil
    return { success = true, cards = drawnCards }
end)

-- ============================================================================
-- Callback: PSA Grading de Carta (Avaliação Oficial)
-- ============================================================================
lib.callback.register('vp_newspaper:server:gradeCardPSA', function(source, cardSlot, caseSlot)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return { success = false, message = 'Jogador não encontrado' } end

    local citizenid = player.PlayerData.citizenid
    local cfg = Config.General.Collectibles
    local cardItemName = cfg.items.card or 'card'
    local caseItemName = cfg.items.psaCase or 'psa_case'
    local cost = cfg.grading.cost or 100

    -- Verifica dinheiro
    if player.PlayerData.money.cash < cost then
        return { success = false, message = ('Dinheiro insuficiente para taxa do PSA ($%d necessários)'):format(cost) }
    end

    -- Verifica o estojo PSA
    local caseItem = exports.ox_inventory:GetSlot(src, caseSlot)
    if not caseItem or caseItem.name ~= caseItemName or caseItem.count < 1 then
        return { success = false, message = 'Estojo avaliador PSA não encontrado' }
    end

    -- Verifica a carta
    local cardItem = exports.ox_inventory:GetSlot(src, cardSlot)
    if not cardItem or cardItem.name ~= cardItemName or cardItem.count < 1 then
        return { success = false, message = 'Carta selecionada inválida' }
    end

    local meta = cardItem.metadata or {}
    if meta.graded then
        return { success = false, message = 'Esta carta já foi avaliada e encapsulada pelo PSA' }
    end

    -- Débito Fail-Closed: remove o estojo e cobra a taxa
    local caseRemoved = exports.ox_inventory:RemoveItem(src, caseItemName, 1, nil, caseSlot)
    if not caseRemoved then
        return { success = false, message = 'Falha ao consumir estojo PSA' }
    end
    player.Functions.RemoveMoney('cash', cost, 'psa-grading-fee')

    -- Cálculo estocástico de subnotas server-side
    local centering = math.random(7, 10)
    local corners = math.random(7, 10)
    local edges = math.random(7, 10)
    local surface = math.random(7, 10)
    local avg = (centering + corners + edges + surface) / 4.0
    local grade = math.floor(avg + 0.5)
    local serial = GenerateCardSerial()

    -- Remove a carta antiga e entrega a carta encapsulada
    exports.ox_inventory:RemoveItem(src, cardItemName, 1, nil, cardSlot)

    local updatedMeta = {
        cardId = meta.cardId or 'card_mayor',
        rarity = meta.rarity or 'basic',
        title = meta.title or 'Carta Colecionável',
        description = meta.description or '',
        image = meta.image or 'cards/mayor.png',
        graded = true,
        grade = grade,
        serial = serial,
        subscores = {
            centering = centering,
            corners = corners,
            edges = edges,
            surface = surface,
        },
    }

    exports.ox_inventory:AddItem(src, cardItemName, 1, updatedMeta)

    -- Atualiza no banco de dados
    MySQL.insert('INSERT INTO vp_cards_shelf (citizenid, card_id, rarity, serial, grade) VALUES (?, ?, ?, ?, ?)', {
        citizenid,
        updatedMeta.cardId,
        updatedMeta.rarity,
        serial,
        grade,
    })

    return {
        success = true,
        grade = grade,
        serial = serial,
        subscores = updatedMeta.subscores,
    }
end)

-- ============================================================================
-- Callback: Consulta de Estante de Colecionáveis
-- ============================================================================
lib.callback.register('vp_newspaper:server:getPlayerCardShelf', function(source)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return {} end

    local citizenid = player.PlayerData.citizenid
    local rows = MySQL.query.await('SELECT card_id, rarity, serial, grade, discovered_at FROM vp_cards_shelf WHERE citizenid = ? ORDER BY grade DESC, discovered_at DESC', { citizenid })
    return rows or {}
end)
