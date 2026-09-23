-- ==========================================================
-- vp_newspaper: Security, Authorization, Distance & Rate Limiting
-- ==========================================================

Security = {}

-- Limites de distância específicos por tipo de ação (metros)
Security.Distances = {
    STAND = 2.5,
    PRINTING = 2.5,
    PAPER = 2.5,
    EDITOR = 2.0,
    GARAGE_SPAWN = 3.5,
    GARAGE_RETURN = 4.5,
    MANAGEMENT = 2.0,
}

-- Configuração de Rate Limiting por Tier
local RateLimitTiers = {
    FAST = { max = 20, window = 10 },     -- 20 requisições / 10s
    ECONOMIC = { max = 5, window = 10 },  -- 5 requisições / 10s
    CRITICAL = { max = 2, window = 10 },  -- 2 requisições / 10s
}

local RateLimitStore = {} ---@type table<string, table<string, { start: number, count: number }>>

---Valida se o jogador possui o cargo e grau necessários
---@param src number
---@param requiredJob string
---@param requiredGrade number
---@param allowAdmin boolean|nil
---@return boolean, string|nil
function Security.IsAuthorized(src, requiredJob, requiredGrade, allowAdmin)
    local player = GetPlayer(src)
    if not player then return false, 'player_not_found' end

    -- Checa permissão administrativa se permitido
    if allowAdmin and IsPlayerAceAllowed(tostring(src), 'command') then
        return true, nil
    end

    local job = player.PlayerData.job
    if not job then return false, 'no_job' end

    if job.name ~= requiredJob then
        return false, 'invalid_job'
    end

    local gradeLevel = (job.grade and job.grade.level) or job.grade or 0
    if gradeLevel < (requiredGrade or 0) then
        return false, 'insufficient_grade'
    end

    return true, nil
end

---Valida distância física vetorial no servidor (OneSync Infinity)
---@param src number
---@param targetCoords vector3
---@param actionType string 'STAND'|'PRINTING'|'PAPER'|'EDITOR'|'GARAGE_SPAWN'|'GARAGE_RETURN'|'MANAGEMENT'
---@return boolean, number
function Security.ValidateDistance(src, targetCoords, actionType)
    if not targetCoords then return false, 999.0 end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false, 999.0
    end

    local pCoords = GetEntityCoords(ped)
    if pCoords == vector3(0, 0, 0) then
        return false, 999.0
    end

    local maxDist = Security.Distances[actionType] or 3.0
    local dist = #(pCoords - targetCoords)

    if dist <= maxDist then
        return true, dist
    end

    print(('^1[vp_newspaper] Alerta de Segurança: Jogador %s violou distância para %s (%.2fm > %.2fm)!^7'):format(src, actionType, dist, maxDist))
    return false, dist
end

---Verifica e incrementa o rate limit por jogador e ação
---@param src number
---@param action string
---@param tier string 'FAST'|'ECONOMIC'|'CRITICAL'
---@return boolean  true = permitido, false = bloqueado por spam
function Security.CheckRateLimit(src, action, tier)
    local cfg = RateLimitTiers[tier] or RateLimitTiers.FAST
    local player = GetPlayer(src)
    local key = player and player.PlayerData.citizenid or tostring(src)

    local now = os.time()
    RateLimitStore[key] = RateLimitStore[key] or {}
    local entry = RateLimitStore[key][action]

    if not entry or (now - entry.start) >= cfg.window then
        RateLimitStore[key][action] = { start = now, count = 1 }
        return true
    end

    if entry.count >= cfg.max then
        print(('^3[vp_newspaper] Rate Limit atingido para jogador %s na ação %s (%d/%ds)^7'):format(key, action, cfg.max, cfg.window))
        return false
    end

    entry.count = entry.count + 1
    return true
end

---Validador estrito de schema de dados
---@param data table
---@param schema table  { [key] = { type = 'string'|'number'|'table', required = boolean, min = number, max = number, maxlen = number } }
---@return boolean, string|nil
function Security.ValidateSchema(data, schema)
    if type(data) ~= 'table' then return false, 'payload_not_table' end

    for field, rules in pairs(schema) do
        local val = data[field]

        if rules.required and (val == nil or val == '') then
            return false, ('campo_obrigatorio_ausente: %s'):format(field)
        end

        if val ~= nil then
            if type(val) ~= rules.type then
                return false, ('tipo_invalido_em: %s (esperado %s, recebido %s)'):format(field, rules.type, type(val))
            end

            if rules.type == 'number' then
                -- Checagem de NaN e Inf
                if val ~= val or val == math.huge or val == -math.huge then
                    return false, ('numero_invalido_nan: %s'):format(field)
                end
                if rules.min and val < rules.min then
                    return false, ('valor_abaixo_minimo: %s'):format(field)
                end
                if rules.max and val > rules.max then
                    return false, ('valor_acima_maximo: %s'):format(field)
                end
            end

            if rules.type == 'string' then
                if rules.maxlen and #val > rules.maxlen then
                    return false, ('string_muito_longa: %s'):format(field)
                end
            end
        end
    end

    return true, nil
end

-- Limpa rate limits ao desconectar
AddEventHandler('playerDropped', function()
    local src = source
    local player = GetPlayer(src)
    local key = player and player.PlayerData.citizenid or tostring(src)
    RateLimitStore[key] = nil
end)
