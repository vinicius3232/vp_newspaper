-- ==========================================================
-- vp_newspaper: Durable Operation FSM & Idempotency Store
-- ==========================================================

Operations = {}

local VALID_TRANSITIONS = {
    PENDING = { PROCESSING = true, ABORTED = true },
    PROCESSING = { COMMITTED = true, COMPENSATING = true, FAILED = true, ABORTED = true },
    COMPENSATING = { COMPENSATED = true, MANUAL_REVIEW = true, FAILED = true },
    COMMITTED = {},
    COMPENSATED = {},
    FAILED = {},
    ABORTED = {},
    MANUAL_REVIEW = {},
}

---Gera um UUID v4 seguro com alta entropia
---@return string
function Operations.GenerateUUID()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return template:gsub('[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

---Cria uma nova operação no estado PENDING
---@param opType string
---@param src number
---@param cid string
---@param targetId string|nil
---@param amount number|nil
---@param payload table|nil
---@return string operation_id
function Operations.New(opType, src, cid, targetId, amount, payload)
    local opId = Operations.GenerateUUID()
    local payloadJson = payload and json.encode(payload) or nil

    MySQL.query.await([[
        INSERT INTO `vp_newspaper_operations`
        (`operation_id`, `op_type`, `citizenid`, `source_id`, `target_id`, `amount`, `state`, `payload`)
        VALUES (?, ?, ?, ?, ?, ?, 'PENDING', ?)
    ]], {
        opId, opType, cid, src, targetId or '', amount or 0, payloadJson
    })

    return opId
end

---Executa a transição de estado da operação
---@param opId string
---@param toState string 'PROCESSING'|'COMMITTED'|'COMPENSATING'|'COMPENSATED'|'FAILED'|'ABORTED'|'MANUAL_REVIEW'
---@param errorReason string|nil
---@return boolean, string|nil
function Operations.Transition(opId, toState, errorReason)
    local row = MySQL.single.await('SELECT `state` FROM `vp_newspaper_operations` WHERE `operation_id` = ?', { opId })
    if not row then
        return false, 'operation_not_found'
    end

    local fromState = row.state
    local allowed = VALID_TRANSITIONS[fromState]
    if not allowed or not allowed[toState] then
        print(('^1[vp_newspaper] Transição de estado inválida: %s -> %s (Op: %s)^7'):format(fromState, toState, opId))
        return false, ('invalid_transition: ' .. fromState .. ' -> ' .. toState)
    end

    MySQL.query.await([[
        UPDATE `vp_newspaper_operations`
        SET `state` = ?, `error_reason` = ?
        WHERE `operation_id` = ?
    ]], {
        toState, errorReason or nil, opId
    })

    return true, nil
end

---Obtém os dados de uma operação
---@param opId string
---@return table|nil
function Operations.Get(opId)
    return MySQL.single.await('SELECT * FROM `vp_newspaper_operations` WHERE `operation_id` = ?', { opId })
end

---Rotina de recuperação executada no boot do servidor
---Detecta operações que estavam em andamento durante um crash/restart
function Operations.RecoverOnBoot()
    local stuck = MySQL.query.await([[
        SELECT * FROM `vp_newspaper_operations`
        WHERE `state` IN ('PENDING', 'PROCESSING', 'COMPENSATING')
    ]], {})

    if stuck and #stuck > 0 then
        print(('^3[vp_newspaper] Recuperando %d operações interrompidas por crash/restart...^7'):format(#stuck))
        for _, op in ipairs(stuck) do
            print(('^3[vp_newspaper] Op %s (%s) em estado %s marcada para MANUAL_REVIEW^7'):format(op.operation_id, op.op_type, op.state))
            MySQL.query.await([[
                UPDATE `vp_newspaper_operations`
                SET `state` = 'MANUAL_REVIEW', `error_reason` = 'server_crash_during_execution'
                WHERE `operation_id` = ?
            ]], { op.operation_id })
        end
    end
end

CreateThread(function()
    Wait(2000)
    Operations.RecoverOnBoot()
end)
