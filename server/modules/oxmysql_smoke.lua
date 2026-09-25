-- ==========================================================
-- vp_newspaper: oxmysql Runtime Contract Smoke Test
-- Runs inside FXServer environment to prove oxmysql driver contracts.
-- ==========================================================

local function RunOxmysqlContractTest()
    print('^3================================================================^7')
    print('^3  vp_newspaper — OXMYSQL REAL RUNTIME CONTRACT SMOKE TEST^7')
    print('^3================================================================^7')

    local testResults = {}
    local function logSubTest(name, passed, detail)
        local status = passed and '^2[PASS]^7' or '^1[FAIL]^7'
        table.insert(testResults, { name = name, passed = passed })
        print(('  %s: %-32s %s'):format(status, name, detail or ''))
    end

    -- Setup Fixture
    local fixtureTable = 'vp_newspaper_oxmysql_qa_fixture'
    MySQL.query.await(('DROP TABLE IF EXISTS `%s`;'):format(fixtureTable))
    MySQL.query.await(('CREATE TABLE `%s` (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(64) NOT NULL, val INT NOT NULL) ENGINE=InnoDB;'):format(fixtureTable))

    -- 1. MySQL.insert.await contract
    local insertId = MySQL.insert.await(('INSERT INTO `%s` (name, val) VALUES (?, ?);'):format(fixtureTable), { 'test_row', 100 })
    local insertPass = type(insertId) == 'number' and insertId > 0
    logSubTest('MySQL.insert.await', insertPass, ('(insertId: %s, type: %s)'):format(tostring(insertId), type(insertId)))

    -- 2. MySQL.update.await contract
    local affected = MySQL.update.await(('UPDATE `%s` SET val = ? WHERE id = ?;'):format(fixtureTable), { 200, insertId })
    local updatePass = type(affected) == 'number' and affected == 1
    logSubTest('MySQL.update.await', updatePass, ('(affectedRows: %s, type: %s)'):format(tostring(affected), type(affected)))

    -- 3. MySQL.query.await (SELECT) contract
    local selectRows = MySQL.query.await(('SELECT * FROM `%s` WHERE id = ?;'):format(fixtureTable), { insertId })
    local selectPass = type(selectRows) == 'table' and #selectRows == 1 and selectRows[1].val == 200
    logSubTest('MySQL.query.await (SELECT)', selectPass, ('(rows: %s, val: %s)'):format(type(selectRows) == 'table' and #selectRows or 0, selectRows and selectRows[1] and selectRows[1].val or 'nil'))

    -- 4. MySQL.query.await (DML Mutation) contract
    local dmlRes = MySQL.query.await(('UPDATE `%s` SET val = ? WHERE id = ?;'):format(fixtureTable), { 300, insertId })
    local dmlPass = false
    local dmlAffected = 'unknown'
    if type(dmlRes) == 'table' and dmlRes.affectedRows then
        dmlPass = dmlRes.affectedRows == 1
        dmlAffected = tostring(dmlRes.affectedRows)
    elseif type(dmlRes) == 'number' then
        dmlPass = dmlRes == 1
        dmlAffected = tostring(dmlRes)
    end
    logSubTest('MySQL.query.await (DML)', dmlPass, ('(affectedRows: %s)'):format(dmlAffected))

    -- 5. MySQL.transaction.await (Valid Commit) contract
    local txCommitSuccess = MySQL.transaction.await({
        { query = ('UPDATE `%s` SET val = ? WHERE id = ?;'):format(fixtureTable), values = { 400, insertId } },
        { query = ('INSERT INTO `%s` (name, val) VALUES (?, ?);'):format(fixtureTable), values = { 'tx_commit_row', 500 } }
    })
    local txCommitPass = txCommitSuccess == true
    logSubTest('MySQL.transaction.await (COMMIT)', txCommitPass, ('(result: %s)'):format(tostring(txCommitSuccess)))

    -- 6. MySQL.transaction.await (Forced Rollback) contract
    local txRollbackResult = MySQL.transaction.await({
        { query = ('UPDATE `%s` SET val = ? WHERE id = ?;'):format(fixtureTable), values = { 999, insertId } },
        { query = ('INSERT INTO `%s_NONEXISTENT_TABLE_FOR_ROLLBACK` (name) VALUES (?);'):format(fixtureTable), values = { 'fail' } }
    })
    local postRbRows = MySQL.query.await(('SELECT val FROM `%s` WHERE id = ?;'):format(fixtureTable), { insertId })
    local valAfterRollback = postRbRows and postRbRows[1] and postRbRows[1].val
    local txRollbackPass = (txRollbackResult == false) and (valAfterRollback == 400)
    logSubTest('MySQL.transaction.await (ROLLBACK)', txRollbackPass, ('(txResult: %s, valueUnchanged: %s)'):format(tostring(txRollbackResult), tostring(valAfterRollback == 400)))

    -- 7. Cleanup Fixture
    MySQL.query.await(('DROP TABLE IF EXISTS `%s`;'):format(fixtureTable))
    local cleanupRows = MySQL.query.await(("SHOW TABLES LIKE '%s';"):format(fixtureTable))
    local cleanupPass = type(cleanupRows) == 'table' and #cleanupRows == 0
    logSubTest('fixture_cleanup', cleanupPass, ('(fixture table dropped cleanly)'))

    -- Summary
    local total = #testResults
    local passed = 0
    for _, t in ipairs(testResults) do
        if t.passed then passed = passed + 1 end
    end
    local allPass = (passed == total)

    print('^3----------------------------------------------------------------^7')
    print(('^3  OXMYSQL CONTRACT STATUS          : %s^7'):format(allPass and ('^2ALL PASS (' .. passed .. '/' .. total .. ')^7') or ('^1FAIL (' .. passed .. '/' .. total .. ')^7')))
    print('^3================================================================^7\n')

    return allPass, passed, total
end

-- Export para execuções automatizadas
exports('runOxmysqlContractTest', RunOxmysqlContractTest)

-- Registro de comando de console de servidor
RegisterCommand('test_oxmysql_contract', function(source, args, raw)
    if source == 0 then
        -- Chamado pelo console do FXServer
        RunOxmysqlContractTest()
    else
        -- Chamado por jogador in-game (apenas se for admin autorizado)
        local isAllowed = false
        if QBCore and QBCore.Functions.HasPermission(source, 'admin') then
            isAllowed = true
        elseif exports.qbx_core and exports.qbx_core:HasPermission(source, 'admin') then
            isAllowed = true
        end

        if isAllowed then
            RunOxmysqlContractTest()
        else
            TriggerClientEvent('vp_newspaper:client:notify', source, 'Sem permissão para executar este teste.', 'error')
        end
    end
end, false)
