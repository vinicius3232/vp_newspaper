-- ==========================================================
-- vp_newspaper: Durable Financial Ledger (Append-Only)
-- ==========================================================

Ledger = {}

---Registra uma movimentação financeira no livro-razão imutável
---@param operationId string
---@param cid string
---@param action string 'deposit'|'withdraw'|'sale_revenue'|'delivery_payout'
---@param amount number
---@param balanceBefore number
---@param balanceAfter number
---@return boolean
function Ledger.Record(operationId, cid, action, amount, balanceBefore, balanceAfter)
    local result = MySQL.insert.await([[
        INSERT INTO `vp_newspaper_ledger`
        (`operation_id`, `citizenid`, `action`, `amount`, `balance_before`, `balance_after`)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        operationId, cid, action, amount, balanceBefore, balanceAfter
    })

    return (result ~= nil and result > 0)
end

---Obtém o histórico de transações formatado para a NUI de gestão
---@param limit number|nil
---@return table
function Ledger.GetRecent(limit)
    limit = limit or 20
    local rows = MySQL.query.await([[
        SELECT `transaction_id`, `operation_id`, `citizenid`, `action`, `amount`,
               `balance_before`, `balance_after`, DATE_FORMAT(`timestamp`, '%H:%i %d/%m') as formatted_date
        FROM `vp_newspaper_ledger`
        ORDER BY `transaction_id` DESC
        LIMIT ?
    ]], { limit })

    local formatted = {}
    if rows then
        for _, r in ipairs(rows) do
            table.insert(formatted, {
                type = (r.action == 'deposit' or r.action == 'sale_revenue') and 'Deposit' or 'Withdraw',
                amount = math.abs(r.amount),
                date = r.formatted_date,
                action = r.action,
                cid = r.citizenid,
            })
        end
    end
    return formatted
end
