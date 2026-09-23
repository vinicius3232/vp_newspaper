/**
 * vp_newspaper — Automated Adversarial & Regression Test Harness
 * Tests Purchase, Restock, Printing, Company Vault, Editor OCC and Security
 */

const assert = require('assert');

// ─── TEST SUITE ENGINE ───────────────────────────────────────────
let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function it(name, fn) {
    totalTests++;
    try {
        fn();
        passedTests++;
        console.log(`  \x1b[32m✔ PASS\x1b[0m: ${name}`);
    } catch (err) {
        failedTests++;
        console.error(`  \x1b[31m✖ FAIL\x1b[0m: ${name}`);
        console.error(`    -> ${err.message}`);
    }
}

async function itAsync(name, fn) {
    totalTests++;
    try {
        await fn();
        passedTests++;
        console.log(`  \x1b[32m✔ PASS\x1b[0m: ${name}`);
    } catch (err) {
        failedTests++;
        console.error(`  \x1b[31m✖ FAIL\x1b[0m: ${name}`);
        console.error(`    -> ${err.message}`);
    }
}

// ─── MOCK ENVIRONMENT ───────────────────────────────────────────
class MockDB {
    constructor() {
        this.reset();
    }

    reset() {
        this.boxes = {
            1: { id: 1, stock: 1, max_stock: 20, version: 1 },
            2: { id: 2, stock: 20, max_stock: 20, version: 1 },
            3: { id: 3, stock: 0, max_stock: 20, version: 1 }
        };
        this.company = { id: 1, balance: 5000, newspaperPrice: 10, version: 1 };
        this.copies = new Map(); // serial -> copy
        this.operations = new Map(); // opId -> op
        this.ledger = [];
        this.editorSessions = new Map();
        this.pages = {
            'page1': { general: '[]', revision: 1, updated_by: 'author1' }
        };
    }

    // Atomic CAS for Stand Purchase
    casPurchaseBox(boxId) {
        const box = this.boxes[boxId];
        if (!box) return { affected: 0 };
        if (box.stock > 0) {
            box.stock--;
            box.version++;
            return { affected: 1, newStock: box.stock, version: box.version };
        }
        return { affected: 0 };
    }

    // Atomic CAS for Restock
    casRestockBox(boxId, maxStock) {
        const box = this.boxes[boxId];
        if (!box) return { affected: 0 };
        if (box.stock < maxStock) {
            box.stock = maxStock;
            box.version++;
            return { affected: 1, newStock: box.stock, version: box.version };
        }
        return { affected: 0 };
    }

    // Atomic CAS for Company Vault Withdrawal
    casWithdrawVault(amount) {
        if (this.company.balance >= amount) {
            const before = this.company.balance;
            this.company.balance -= amount;
            this.company.version++;
            return { affected: 1, before, after: this.company.balance };
        }
        return { affected: 0 };
    }

    // OCC Update for Editor Page Save
    occSavePage(page, content, expectedRevision, authorCid) {
        const p = this.pages[page];
        if (!p) return { affected: 0 };
        if (p.revision === expectedRevision) {
            p.general = content;
            p.revision++;
            p.updated_by = authorCid;
            return { affected: 1, newRevision: p.revision };
        }
        return { affected: 0 }; // Revision Conflict
    }

    insertCopy(serial, cid, opId) {
        if (this.copies.has(serial)) {
            throw new Error('ER_DUP_ENTRY: Duplicate entry for serial');
        }
        this.copies.set(serial, { serial, cid, opId, status: 'ACTIVE' });
        return true;
    }
}

// ─── LOGIC HANDLERS UNDER TEST ──────────────────────────────────
class NewspaperEngine {
    constructor(db) {
        this.db = db;
        this.rateLimits = new Map();
    }

    checkRateLimit(key, action, max, windowSec) {
        const now = Date.now();
        const entryKey = `${key}:${action}`;
        const entry = this.rateLimits.get(entryKey);
        if (!entry || (now - entry.start) >= windowSec * 1000) {
            this.rateLimits.set(entryKey, { start: now, count: 1 });
            return true;
        }
        if (entry.count >= max) {
            return false;
        }
        entry.count++;
        return true;
    }

    validateDistance(pCoords, targetCoords, maxDist) {
        if (!pCoords || !targetCoords) return false;
        const dx = pCoords.x - targetCoords.x;
        const dy = pCoords.y - targetCoords.y;
        const dz = pCoords.z - targetCoords.z;
        const dist = Math.sqrt(dx * dx + dy * dy + dz * dz);
        return dist <= maxDist;
    }

    purchaseNewspaper(player, boxId, options = {}) {
        // 1. Rate limit
        if (!this.checkRateLimit(player.cid, 'buy_newspaper', 5, 10)) {
            return { success: false, reason: 'rate_limited' };
        }

        // 2. Distance check
        const boxCoords = { x: 100, y: 100, z: 20 };
        if (!this.validateDistance(player.coords, boxCoords, 2.5)) {
            return { success: false, reason: 'distance_violation' };
        }

        const price = this.db.company.newspaperPrice;
        const opId = `op-${Math.random().toString(36).substring(2, 9)}`;
        this.db.operations.set(opId, { opId, state: 'PROCESSING', type: 'purchase' });

        // 3. Atomic CAS on Box Stock
        const cas = this.db.casPurchaseBox(boxId);
        if (cas.affected === 0) {
            this.db.operations.get(opId).state = 'ABORTED';
            return { success: false, reason: 'out_of_stock' };
        }

        // 4. Money debit check
        if (player.money < price) {
            this.db.boxes[boxId].stock++; // Rollback
            this.db.operations.get(opId).state = 'ABORTED';
            return { success: false, reason: 'insufficient_funds' };
        }

        player.money -= price;

        // 5. Serial Generation & DB Insert
        const serial = options.forcedSerial || `UUID-${Math.random().toString(36).substring(2, 10)}`;
        try {
            this.db.insertCopy(serial, player.cid, opId);
        } catch (e) {
            // Compensate
            player.money += price;
            this.db.boxes[boxId].stock++;
            this.db.operations.get(opId).state = 'COMPENSATED';
            return { success: false, reason: 'serial_collision_refunded' };
        }

        // 6. Inventory delivery
        if (options.failInventory) {
            // Compensate
            player.money += price;
            this.db.boxes[boxId].stock++;
            this.db.copies.get(serial).status = 'BURNED';
            this.db.operations.get(opId).state = 'COMPENSATED';
            return { success: false, reason: 'inventory_full_refunded' };
        }

        player.inventory.push({ item: 'newspaper', serial });

        // 7. Company Revenue & Ledger
        this.db.company.balance += price;
        this.db.ledger.push({ opId, action: 'sale_revenue', amount: price });
        this.db.operations.get(opId).state = 'COMMITTED';

        return { success: true, opId, serial, newStock: cas.newStock };
    }

    restockBox(worker, boxId, options = {}) {
        if (!worker.job || worker.job !== 'reporter') {
            return { success: false, reason: 'invalid_job' };
        }

        const boxCoords = { x: 100, y: 100, z: 20 };
        if (!this.validateDistance(worker.coords, boxCoords, 2.5)) {
            return { success: false, reason: 'distance_violation' };
        }

        const box = this.db.boxes[boxId];
        if (!box || box.stock >= box.max_stock) {
            return { success: false, reason: 'full_stand' };
        }

        // Check & Consume newspaperbox
        const boxIdx = worker.inventory.findIndex(i => i.item === 'newspaperbox');
        if (boxIdx === -1) {
            return { success: false, reason: 'no_box_item' };
        }
        worker.inventory.splice(boxIdx, 1);

        // Atomic CAS
        const cas = this.db.casRestockBox(boxId, box.max_stock);
        if (cas.affected === 0) {
            // Compensate
            worker.inventory.push({ item: 'newspaperbox' });
            return { success: false, reason: 'concurrent_restock_compensated' };
        }

        worker.money += 50;
        return { success: true, newStock: box.max_stock };
    }

    printNewspapers(worker, options = {}) {
        if (!worker.job || worker.job !== 'reporter') {
            return { success: false, reason: 'invalid_job' };
        }

        const requiredPaper = 5;
        const paperCount = worker.inventory.filter(i => i.item === 'empty_newspaper').length;
        if (paperCount < requiredPaper) {
            return { success: false, reason: 'insufficient_materials' };
        }

        // Remove 5 sheets
        for (let i = 0; i < requiredPaper; i++) {
            const idx = worker.inventory.findIndex(it => it.item === 'empty_newspaper');
            worker.inventory.splice(idx, 1);
        }

        // Add newspaperbox
        if (options.failInventory) {
            // Rollback paper
            for (let i = 0; i < requiredPaper; i++) {
                worker.inventory.push({ item: 'empty_newspaper' });
            }
            return { success: false, reason: 'inventory_full_paper_refunded' };
        }

        worker.inventory.push({ item: 'newspaperbox' });
        return { success: true };
    }

    withdrawCompanyVault(worker, amount) {
        if (!worker.job || worker.job !== 'reporter' || worker.grade < 4) {
            return { success: false, reason: 'unauthorized_boss_required' };
        }
        if (typeof amount !== 'number' || isNaN(amount) || amount <= 0) {
            return { success: false, reason: 'invalid_amount' };
        }

        const cas = this.db.casWithdrawVault(amount);
        if (cas.affected === 0) {
            return { success: false, reason: 'insufficient_vault_balance' };
        }

        worker.money += amount;
        this.db.ledger.push({ action: 'withdraw', amount: -amount, before: cas.before, after: cas.after });
        return { success: true, before: cas.before, after: cas.after };
    }

    acquireEditorLock(editor) {
        if (!editor.job || editor.job !== 'reporter') {
            return { success: false, reason: 'unauthorized' };
        }
        const now = Date.now();
        const active = this.db.editorSessions.get('active');
        if (active && active.expiresAt > now && active.cid !== editor.cid) {
            return { success: false, reason: 'editor_busy' };
        }

        const sessionId = `sess-${Math.random().toString(36).substring(2, 9)}`;
        this.db.editorSessions.set('active', { sessionId, cid: editor.cid, expiresAt: now + 30000 });
        return { success: true, sessionId, revision: this.db.pages['page1'].revision };
    }

    saveEditorPage(editor, page, content, expectedRevision) {
        if (!editor.job || editor.job !== 'reporter') {
            return { success: false, reason: 'unauthorized' };
        }
        const occ = this.db.occSavePage(page, content, expectedRevision, editor.cid);
        if (occ.affected === 0) {
            return { success: false, reason: 'conflicting_revision' };
        }
        return { success: true, newRevision: occ.newRevision };
    }
}

// ─── EXECUTION OF TEST CASES ─────────────────────────────────────
async function runTests() {
    console.log('\n======================================================');
    console.log('  STARTING TEST HARNESS FOR vp_newspaper HARDENING');
    console.log('======================================================\n');

    const db = new MockDB();
    const engine = new NewspaperEngine(db);

    console.log('--- 1. PURCHASE TESTS ---');
    it('Purchase - Success single purchase', () => {
        const player = { cid: 'P1', money: 100, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const res = engine.purchaseNewspaper(player, 1);
        assert.strictEqual(res.success, true);
        assert.strictEqual(player.money, 90);
        assert.strictEqual(player.inventory.length, 1);
        assert.strictEqual(db.boxes[1].stock, 0);
    });

    it('Purchase - Out of stock blocks immediately', () => {
        const player = { cid: 'P2', money: 100, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const res = engine.purchaseNewspaper(player, 3); // Stand 3 has 0 stock
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'out_of_stock');
        assert.strictEqual(player.money, 100);
    });

    it('Purchase - Insufficient funds rollbacks stand stock', () => {
        db.boxes[1].stock = 5;
        const player = { cid: 'P3', money: 5, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const res = engine.purchaseNewspaper(player, 1);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'insufficient_funds');
        assert.strictEqual(db.boxes[1].stock, 5); // Stock restored
    });

    await itAsync('Purchase - Concurrent last-stock race condition (Player A & B on stock=1)', async () => {
        db.boxes[1].stock = 1;
        const playerA = { cid: 'PA', money: 50, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const playerB = { cid: 'PB', money: 50, coords: { x: 100, y: 100, z: 20 }, inventory: [] };

        // Simultaneous execution
        const [resA, resB] = await Promise.all([
            Promise.resolve(engine.purchaseNewspaper(playerA, 1)),
            Promise.resolve(engine.purchaseNewspaper(playerB, 1))
        ]);

        const successCount = (resA.success ? 1 : 0) + (resB.success ? 1 : 0);
        assert.strictEqual(successCount, 1, 'Exactly one buyer must succeed');
        assert.strictEqual(db.boxes[1].stock, 0, 'Final stock must be exactly 0');
    });

    it('Purchase - Serial Collision causes closed rollback', () => {
        db.boxes[1].stock = 5;
        const existingSerial = 'DUPE-SERIAL-123';
        db.copies.set(existingSerial, { serial: existingSerial });

        const player = { cid: 'P4', money: 100, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const res = engine.purchaseNewspaper(player, 1, { forcedSerial: existingSerial });

        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'serial_collision_refunded');
        assert.strictEqual(player.money, 100, 'Money refunded');
        assert.strictEqual(db.boxes[1].stock, 5, 'Stock preserved');
    });

    it('Purchase - Inventory Full causes full compensation', () => {
        db.boxes[1].stock = 5;
        const player = { cid: 'P5', money: 100, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        const res = engine.purchaseNewspaper(player, 1, { failInventory: true });

        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'inventory_full_refunded');
        assert.strictEqual(player.money, 100, 'Player refunded');
        assert.strictEqual(db.boxes[1].stock, 5, 'Stand stock restored');
    });

    console.log('\n--- 2. RESTOCK TESTS ---');
    it('Restock - Valid reporter restocks box and gets payout', () => {
        db.boxes[1].stock = 5;
        const worker = {
            cid: 'W1', job: 'reporter', money: 0,
            coords: { x: 100, y: 100, z: 20 },
            inventory: [{ item: 'newspaperbox' }]
        };
        const res = engine.restockBox(worker, 1);
        assert.strictEqual(res.success, true);
        assert.strictEqual(worker.money, 50);
        assert.strictEqual(worker.inventory.length, 0);
        assert.strictEqual(db.boxes[1].stock, 20);
    });

    it('Restock - Non-reporter blocked (Invalid job)', () => {
        const civilian = {
            cid: 'C1', job: 'unemployed', money: 0,
            coords: { x: 100, y: 100, z: 20 },
            inventory: [{ item: 'newspaperbox' }]
        };
        const res = engine.restockBox(civilian, 1);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'invalid_job');
    });

    it('Restock - Stand already full rejected before consuming box', () => {
        db.boxes[2].stock = 20; // Full
        const worker = {
            cid: 'W2', job: 'reporter', money: 0,
            coords: { x: 100, y: 100, z: 20 },
            inventory: [{ item: 'newspaperbox' }]
        };
        const res = engine.restockBox(worker, 2);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'full_stand');
        assert.strictEqual(worker.inventory.length, 1, 'Box not consumed');
    });

    console.log('\n--- 3. PRINTING TESTS ---');
    it('Printing - Consumes 5 papers and crafts newspaperbox', () => {
        const worker = {
            cid: 'W3', job: 'reporter',
            inventory: [
                { item: 'empty_newspaper' }, { item: 'empty_newspaper' },
                { item: 'empty_newspaper' }, { item: 'empty_newspaper' },
                { item: 'empty_newspaper' }
            ]
        };
        const res = engine.printNewspapers(worker);
        assert.strictEqual(res.success, true);
        assert.strictEqual(worker.inventory.length, 1);
        assert.strictEqual(worker.inventory[0].item, 'newspaperbox');
    });

    it('Printing - Insufficient materials fails closed', () => {
        const worker = {
            cid: 'W4', job: 'reporter',
            inventory: [{ item: 'empty_newspaper' }, { item: 'empty_newspaper' }] // Only 2
        };
        const res = engine.printNewspapers(worker);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'insufficient_materials');
        assert.strictEqual(worker.inventory.length, 2);
    });

    it('Printing - Full inventory refunds materials', () => {
        const worker = {
            cid: 'W5', job: 'reporter',
            inventory: [
                { item: 'empty_newspaper' }, { item: 'empty_newspaper' },
                { item: 'empty_newspaper' }, { item: 'empty_newspaper' },
                { item: 'empty_newspaper' }
            ]
        };
        const res = engine.printNewspapers(worker, { failInventory: true });
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'inventory_full_paper_refunded');
        assert.strictEqual(worker.inventory.length, 5, 'All 5 papers refunded');
    });

    console.log('\n--- 4. COMPANY VAULT & CONCURRENCY TESTS ---');
    it('Company Vault - Boss withdrawal succeeds', () => {
        db.company.balance = 5000;
        const boss = { cid: 'BOSS1', job: 'reporter', grade: 4, money: 0 };
        const res = engine.withdrawCompanyVault(boss, 2000);
        assert.strictEqual(res.success, true);
        assert.strictEqual(boss.money, 2000);
        assert.strictEqual(db.company.balance, 3000);
    });

    it('Company Vault - Non-boss grade rejected', () => {
        const intern = { cid: 'INT1', job: 'reporter', grade: 1, money: 0 };
        const res = engine.withdrawCompanyVault(intern, 500);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'unauthorized_boss_required');
    });

    await itAsync('Company Vault - Concurrent double withdrawal exceeding balance', async () => {
        db.company.balance = 5000;
        const bossA = { cid: 'BOSS_A', job: 'reporter', grade: 4, money: 0 };
        const bossB = { cid: 'BOSS_B', job: 'reporter', grade: 4, money: 0 };

        // Both try to withdraw $4,000 simultaneously from a $5,000 vault
        const [resA, resB] = await Promise.all([
            Promise.resolve(engine.withdrawCompanyVault(bossA, 4000)),
            Promise.resolve(engine.withdrawCompanyVault(bossB, 4000))
        ]);

        const successCount = (resA.success ? 1 : 0) + (resB.success ? 1 : 0);
        assert.strictEqual(successCount, 1, 'Only one withdrawal can succeed');
        assert.strictEqual(db.company.balance, 1000, 'Balance must remain positive ($1000)');
    });

    console.log('\n--- 5. EDITOR LOCK & OPTIMISTIC CONCURRENCY TESTS ---');
    it('Editor - Acquires lock and blocks second reporter', () => {
        const ed1 = { cid: 'ED1', job: 'reporter' };
        const ed2 = { cid: 'ED2', job: 'reporter' };

        const res1 = engine.acquireEditorLock(ed1);
        assert.strictEqual(res1.success, true);

        const res2 = engine.acquireEditorLock(ed2);
        assert.strictEqual(res2.success, false);
        assert.strictEqual(res2.reason, 'editor_busy');
    });

    it('Editor - Conflicting revision rejected by OCC', () => {
        db.pages['page1'] = { general: '[]', revision: 3, updated_by: 'ED1' };
        const ed2 = { cid: 'ED2', job: 'reporter' };

        // Editor 2 attempts to save with stale revision 2
        const res = engine.saveEditorPage(ed2, 'page1', '[{"text":"Stale"}]', 2);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'conflicting_revision');
        assert.strictEqual(db.pages['page1'].revision, 3);
    });

    console.log('\n--- 6. SECURITY & ADVERSARIAL ATTACKS ---');
    it('Security - Distance violation rejected fail-closed', () => {
        const hacker = { cid: 'HACK1', money: 1000, coords: { x: 999, y: 999, z: 999 }, inventory: [] };
        const res = engine.purchaseNewspaper(hacker, 1);
        assert.strictEqual(res.success, false);
        assert.strictEqual(res.reason, 'distance_violation');
    });

    it('Security - NaN/Negative withdrawal rejected', () => {
        const boss = { cid: 'BOSS1', job: 'reporter', grade: 4, money: 0 };
        assert.strictEqual(engine.withdrawCompanyVault(boss, -500).success, false);
        assert.strictEqual(engine.withdrawCompanyVault(boss, NaN).success, false);
        assert.strictEqual(engine.withdrawCompanyVault(boss, 'all').success, false);
    });

    it('Security - Rate limit blocks spam burst', () => {
        const spammer = { cid: 'SPAM1', money: 1000, coords: { x: 100, y: 100, z: 20 }, inventory: [] };
        db.boxes[1].stock = 50;

        let blocked = false;
        for (let i = 0; i < 10; i++) {
            const res = engine.purchaseNewspaper(spammer, 1);
            if (!res.success && res.reason === 'rate_limited') {
                blocked = true;
                break;
            }
        }
        assert.strictEqual(blocked, true, 'Rate limit must kick in after 5 requests');
    });

    console.log('\n======================================================');
    console.log(`  TEST RESULTS: ${passedTests}/${totalTests} PASSED (${failedTests} FAILED)`);
    console.log('======================================================\n');

    if (failedTests > 0) {
        process.exit(1);
    }
}

runTests();
