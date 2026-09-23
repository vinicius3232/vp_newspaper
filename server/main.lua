-- ==========================================================
-- vp_newspaper: Core Server, Framework Bridge & Usables
-- ==========================================================

QBCore = nil

if GetResourceState('qbx_core') == 'started' then
    -- Qbox Core
    print('^2[vp_newspaper] Integrado com QBX Core.^7')
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    print('^2[vp_newspaper] Integrado com QBCore legado/padrão.^7')
end

---Obtém objeto do jogador unificado
---@param src number
---@return table|nil
function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayer(src)
    elseif QBCore then
        return QBCore.Functions.GetPlayer(src)
    end
    return nil
end

---Obtém jogador por CitizenID
---@param cid string
---@return table|nil
function GetPlayerByCitizenId(cid)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayerByCitizenId(cid)
    elseif QBCore then
        return QBCore.Functions.GetPlayerByCitizenId(cid)
    end
    return nil
end

---Verifica saldo do jogador
---@param src number
---@param moneyType string 'cash'|'bank'
---@return number
function GetPlayerMoney(src, moneyType)
    local player = GetPlayer(src)
    if not player then return 0 end
    return player.Functions.GetMoney(moneyType) or 0
end

---Remove dinheiro com segurança
---@param src number
---@param moneyType string 'cash'|'bank'
---@param amount number
---@param reason string
---@return boolean
function RemovePlayerMoney(src, moneyType, amount, reason)
    local player = GetPlayer(src)
    if not player then return false end
    if player.Functions.GetMoney(moneyType) < amount then return false end
    return player.Functions.RemoveMoney(moneyType, amount, reason or 'vp_newspaper')
end

---Adiciona dinheiro com segurança
---@param src number
---@param moneyType string 'cash'|'bank'
---@param amount number
---@param reason string
---@return boolean
function AddPlayerMoney(src, moneyType, amount, reason)
    local player = GetPlayer(src)
    if not player then return false end
    return player.Functions.AddMoney(moneyType, amount, reason or 'vp_newspaper')
end

---Envio de notificação para o jogador
---@param src number
---@param msg string
---@param notifyType string|nil 'success'|'error'|'info'
function NotifyPlayer(src, msg, notifyType)
    notifyType = notifyType or 'info'
    TriggerClientEvent('vp_newspaper:client:notify', src, msg, notifyType)
end

---Envia log no Discord se configurado
---@param title string
---@param message string
---@param color number|nil
function SendDiscordLog(title, message, color)
    local webhook = Config.General.WebhookURL
    if not webhook or webhook == '' then return end

    local embed = {
        {
            ['title'] = title,
            ['description'] = message,
            ['color'] = color or 3447003,
            ['footer'] = { ['text'] = 'vp_newspaper • ' .. os.date('%d/%m/%Y %H:%M:%S') }
        }
    }
    PerformHttpRequest(webhook, function(err, text, headers) end, 'POST', json.encode({ username = 'Weazel News Log', embeds = embed }), { ['Content-Type'] = 'application/json' })
end

-- ==========================================================
-- Registro de Item Usável: Jornal
-- ==========================================================

CreateThread(function()
    if Config.UseOxInventory and GetResourceState('ox_inventory') == 'started' then
        -- ox_inventory hook de uso
        exports('useNewspaper', function(event, item, inventory, slot, data)
            if event == 'usingItem' then
                local src = inventory.id
                TriggerClientEvent('vp_newspaper:client:openReader', src)
                return false
            end
        end)
    end

    -- QBCore Useable Item fallback
    if QBCore then
        QBCore.Functions.CreateUseableItem(Config.General.newspaperItemName, function(source, item)
            TriggerClientEvent('vp_newspaper:client:openReader', source)
        end)
    end
end)

-- Notificação genérica vinda de outros módulos
RegisterNetEvent('vp_newspaper:server:notify', function(msg, nType)
    local src = source
    NotifyPlayer(src, msg, nType)
end)
