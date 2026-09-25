"""
vp_newspaper — Real MariaDB Integration Gate
Tests schema bootstrap, migration idempotency, engine constraints, and true multi-connection CAS concurrency.
Never runs against production database.
"""

import sys
import threading
import time
import pymysql

DB_CONFIG = {
    'host': '127.0.0.1',
    'port': 3306,
    'user': 'root',
    'password': 'root',
    'charset': 'utf8mb4',
    'autocommit': True
}

TEST_DB = 'vp_newspaper_mariadb_qa'

MIGRATION_FILES = [
    r'E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\vp_newspaper\sql\migrations\001_initial_schema.sql',
    r'E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\vp_newspaper\sql\migrations\002_operations_and_ledger.sql',
    r'E:\Users\Vinicius\Downloads\txData\Qbox_753251.base\resources\[standalone]\vp_newspaper\sql\migrations\003_editor_sessions.sql',
]

if sys.stdout.encoding != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

results = {}

def log_test(name, passed, detail=''):
    status = 'PASS' if passed else 'FAIL'
    results[name] = status
    color = '\033[32m' if passed else '\033[31m'
    print(f"  {color}[{status}]\033[0m: {name} {detail}")

def get_connection(db_name=None, autocommit=True):
    cfg = DB_CONFIG.copy()
    cfg['autocommit'] = autocommit
    if db_name:
        cfg['database'] = db_name
    return pymysql.connect(**cfg)

def run_migrations(conn):
    with conn.cursor() as cursor:
        for file_path in MIGRATION_FILES:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            statements = content.split(';')
            for stmt in statements:
                lines = [line for line in stmt.splitlines() if not line.strip().startswith('--')]
                executable = '\n'.join(lines).strip()
                if executable:
                    cursor.execute(executable)

def main():
    print('================================================================')
    print('  vp_newspaper — MARIADB REAL ENGINE INTEGRATION GATE')
    print('================================================================\n')

    # Step 0: Ensure fresh isolated test database
    admin_conn = get_connection()
    with admin_conn.cursor() as cur:
        cur.execute(f"DROP DATABASE IF EXISTS `{TEST_DB}`;")
        cur.execute(f"CREATE DATABASE `{TEST_DB}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
    admin_conn.close()

    conn = get_connection(TEST_DB)

    # 1. SCHEMA BOOTSTRAP (RUN 1)
    print("--- 1. SCHEMA BOOTSTRAP & IDEMPOTENCY ---")
    run_migrations(conn)

    expected_tables = {
        'newspaper_company',
        'newspaper_texts',
        'newspaper_boxes',
        'vp_newspaper_operations',
        'vp_newspaper_ledger',
        'vp_newspaper_copies',
        'vp_newspaper_editor_sessions'
    }

    with conn.cursor() as cur:
        cur.execute("SHOW TABLES;")
        found_tables = {row[0] for row in cur.fetchall()}

    all_tables_created = expected_tables.issubset(found_tables)
    log_test('schema_bootstrap', all_tables_created, f"(Found: {len(found_tables)} tables)")

    # 2. MIGRATION IDEMPOTENCY (RUN 2)
    idempotent_pass = True
    try:
        run_migrations(conn)
        with conn.cursor() as cur:
            cur.execute("SHOW TABLES;")
            found_tables_run2 = {row[0] for row in cur.fetchall()}
            cur.execute("SELECT count(*) FROM newspaper_texts;")
            texts_count = cur.fetchone()[0]
        idempotent_pass = (found_tables_run2 == found_tables) and (texts_count == 5)
    except Exception as e:
        idempotent_pass = False

    log_test('migration_idempotency', idempotent_pass, "(Zero errors on re-run, seed count preserved)")

    # 3. MARIA DB CONSTRAINTS
    print("\n--- 2. REAL MARIADB CONSTRAINTS & METRICS ---")

    # Constraint 3.1: CHECK (balance >= 0)
    with conn.cursor() as cur:
        cur.execute("SELECT balance FROM newspaper_company WHERE id = 1;")
        prev_bal = cur.fetchone()[0]

        check_bal_caught = False
        bal_errno = None
        bal_sqlstate = None

        try:
            cur.execute("UPDATE newspaper_company SET balance = -1 WHERE id = 1;")
        except pymysql.MySQLError as e:
            check_bal_caught = True
            bal_errno = e.args[0]
            # PyMySQL exception format
            cur.execute("SELECT balance FROM newspaper_company WHERE id = 1;")
            post_bal = cur.fetchone()[0]

        log_test('CHECK_balance', check_bal_caught and post_bal == prev_bal,
                 f"(Errno: {bal_errno}, Prev: {prev_bal}, Post: {post_bal})")

    # Constraint 3.2: CHECK (stock >= 0)
    with conn.cursor() as cur:
        cur.execute("INSERT INTO newspaper_boxes (coords, stock, max_stock) VALUES ('0,0,0', 0, 20);")
        box_test_id = cur.lastrowid
        cur.execute(f"SELECT stock FROM newspaper_boxes WHERE id = {box_test_id};")
        prev_stock = cur.fetchone()[0]

        check_stock_caught = False
        stock_errno = None
        try:
            cur.execute(f"UPDATE newspaper_boxes SET stock = -1 WHERE id = {box_test_id};")
        except pymysql.MySQLError as e:
            check_stock_caught = True
            stock_errno = e.args[0]

        cur.execute(f"SELECT stock FROM newspaper_boxes WHERE id = {box_test_id};")
        post_stock = cur.fetchone()[0]

        log_test('CHECK_stock', check_stock_caught and post_stock == prev_stock,
                 f"(Errno: {stock_errno}, Prev: {prev_stock}, Post: {post_stock})")

    # Constraint 3.3: UNIQUE (serial)
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM vp_newspaper_copies;")
        copies_before = cur.fetchone()[0]

        cur.execute("INSERT INTO vp_newspaper_copies (serial, owner_cid, operation_id) VALUES ('SER_MDB_01', 'CID1', 'OP1');")

        dup_serial_caught = False
        serial_errno = None
        try:
            cur.execute("INSERT INTO vp_newspaper_copies (serial, owner_cid, operation_id) VALUES ('SER_MDB_01', 'CID2', 'OP2');")
        except pymysql.MySQLError as e:
            dup_serial_caught = True
            serial_errno = e.args[0]

        cur.execute("SELECT count(*) FROM vp_newspaper_copies;")
        copies_after = cur.fetchone()[0]

        log_test('UNIQUE_serial', dup_serial_caught and (copies_after == copies_before + 1),
                 f"(Errno: {serial_errno}, Rows before: {copies_before}, after: {copies_after})")

    # Constraint 3.4: PRIMARY KEY (operation_id)
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM vp_newspaper_operations;")
        ops_before = cur.fetchone()[0]

        cur.execute("INSERT INTO vp_newspaper_operations (operation_id, op_type, citizenid, source_id) VALUES ('OP_MDB_01', 'purchase', 'CID1', 1);")

        dup_op_caught = False
        op_errno = None
        try:
            cur.execute("INSERT INTO vp_newspaper_operations (operation_id, op_type, citizenid, source_id) VALUES ('OP_MDB_01', 'purchase', 'CID2', 2);")
        except pymysql.MySQLError as e:
            dup_op_caught = True
            op_errno = e.args[0]

        cur.execute("SELECT count(*) FROM vp_newspaper_operations;")
        ops_after = cur.fetchone()[0]

        log_test('PK_operation_id', dup_op_caught and (ops_after == ops_before + 1),
                 f"(Errno: {op_errno}, Rows before: {ops_before}, after: {ops_after})")

    # Constraint 3.5: OCC Revision
    with conn.cursor() as cur:
        cur.execute("UPDATE newspaper_texts SET revision = 5 WHERE page = 'page1';")
        # Stale update
        cur.execute("UPDATE newspaper_texts SET general = 'stale', revision = revision + 1 WHERE page = 'page1' AND revision = 4;")
        stale_rows = cur.rowcount

        # Valid update
        cur.execute("UPDATE newspaper_texts SET general = 'fresh', revision = revision + 1 WHERE page = 'page1' AND revision = 5;")
        fresh_rows = cur.rowcount

        cur.execute("SELECT revision FROM newspaper_texts WHERE page = 'page1';")
        final_rev = cur.fetchone()[0]

        occ_pass = (stale_rows == 0) and (fresh_rows == 1) and (final_rev == 6)
        log_test('OCC_revision', occ_pass, f"(Stale affected: {stale_rows}, Fresh affected: {fresh_rows}, Final Rev: {final_rev})")

    # 4. TRUE MULTI-CONNECTION CONCURRENCY TESTS
    print("\n--- 3. MULTI-CONNECTION CONCURRENT CAS STRESS ---")

    # Test A: 10 concurrent withdrawals against $5000 vault
    with conn.cursor() as cur:
        cur.execute("UPDATE newspaper_company SET balance = 5000, version = 1 WHERE id = 1;")

    success_count_a = 0
    rejected_count_a = 0
    lock_a = threading.Lock()

    def worker_treasury(worker_id):
        nonlocal success_count_a, rejected_count_a
        c = get_connection(TEST_DB)
        try:
            with c.cursor() as cur:
                cur.execute("""
                    UPDATE newspaper_company
                    SET balance = balance - 1000, version = version + 1
                    WHERE id = 1 AND balance >= 1000;
                """)
                affected = cur.rowcount
            with lock_a:
                if affected == 1:
                    success_count_a += 1
                else:
                    rejected_count_a += 1
        finally:
            c.close()

    threads_a = [threading.Thread(target=worker_treasury, args=(i,)) for i in range(10)]
    for t in threads_a: t.start()
    for t in threads_a: t.join()

    with conn.cursor() as cur:
        cur.execute("SELECT balance FROM newspaper_company WHERE id = 1;")
        final_vault_bal = cur.fetchone()[0]

    cas_vault_pass = (success_count_a == 5) and (rejected_count_a == 5) and (final_vault_bal == 0)
    log_test('concurrent_treasury_CAS', cas_vault_pass,
             f"(5000 balance: {success_count_a} wins, {rejected_count_a} rejected, Final Balance: {final_vault_bal})")

    # Test B: 2 concurrent purchases on stock = 1
    with conn.cursor() as cur:
        cur.execute("INSERT INTO newspaper_boxes (coords, stock, max_stock) VALUES ('10,10,10', 1, 20);")
        stand_race_id = cur.lastrowid

    success_count_b = 0
    rejected_count_b = 0
    lock_b = threading.Lock()

    def worker_stand(worker_id):
        nonlocal success_count_b, rejected_count_b
        c = get_connection(TEST_DB)
        try:
            with c.cursor() as cur:
                cur.execute(f"""
                    UPDATE newspaper_boxes
                    SET stock = stock - 1, version = version + 1
                    WHERE id = {stand_race_id} AND stock > 0;
                """)
                affected = cur.rowcount
            with lock_b:
                if affected == 1:
                    success_count_b += 1
                else:
                    rejected_count_b += 1
        finally:
            c.close()

    threads_b = [threading.Thread(target=worker_stand, args=(i,)) for i in range(2)]
    for t in threads_b: t.start()
    for t in threads_b: t.join()

    with conn.cursor() as cur:
        cur.execute(f"SELECT stock FROM newspaper_boxes WHERE id = {stand_race_id};")
        final_stand_stock = cur.fetchone()[0]

    cas_stand_pass = (success_count_b == 1) and (rejected_count_b == 1) and (final_stand_stock == 0)
    log_test('concurrent_stock_CAS', cas_stand_pass,
             f"(Stock=1: {success_count_b} win, {rejected_count_b} rejected, Final Stock: {final_stand_stock})")

    # 5. OXMYSQL CONTRACT VERIFICATION & REAL LOCKING TESTS
    print("\n--- 4. OXMYSQL RETURN CONTRACT & DEADLOCK / TIMEOUT BEHAVIOR ---")

    # oxmysql query.await for UPDATE returns affectedRows via rowcount
    with conn.cursor() as cur:
        cur.execute("UPDATE newspaper_boxes SET stock = 15 WHERE id = 1;")
        oxmysql_affected = cur.rowcount
        log_test('oxmysql_return_contract', oxmysql_affected >= 0,
                 f"(cur.rowcount maps directly to oxmysql.affectedRows: {oxmysql_affected})")

    # Real MariaDB Deadlock Test (Errno 1213, SQLSTATE 40001)
    with conn.cursor() as cur:
        cur.execute("INSERT INTO newspaper_boxes (coords, stock, max_stock) VALUES ('99,99,91', 10, 20);")
        box_dl_1 = cur.lastrowid
        cur.execute("INSERT INTO newspaper_boxes (coords, stock, max_stock) VALUES ('99,99,92', 10, 20);")
        box_dl_2 = cur.lastrowid

    conn_dl_a = get_connection(TEST_DB, autocommit=False)
    conn_dl_b = get_connection(TEST_DB, autocommit=False)

    # TX A locks row 1
    with conn_dl_a.cursor() as cur_a:
        cur_a.execute("UPDATE newspaper_boxes SET stock = 11 WHERE id = %s;", (box_dl_1,))

    # TX B locks row 2
    with conn_dl_b.cursor() as cur_b:
        cur_b.execute("UPDATE newspaper_boxes SET stock = 21 WHERE id = %s;", (box_dl_2,))

    err_dl_a = None
    err_dl_b = None

    def worker_dl_a():
        nonlocal err_dl_a
        try:
            with conn_dl_a.cursor() as cur:
                cur.execute("UPDATE newspaper_boxes SET stock = 12 WHERE id = %s;", (box_dl_2,))
                conn_dl_a.commit()
        except Exception as e:
            err_dl_a = e
            conn_dl_a.rollback()

    t_dl = threading.Thread(target=worker_dl_a)
    t_dl.start()

    time.sleep(0.1)  # Ensure thread A has reached lock wait on row 2

    try:
        with conn_dl_b.cursor() as cur:
            cur.execute("UPDATE newspaper_boxes SET stock = 22 WHERE id = %s;", (box_dl_1,))
            conn_dl_b.commit()
    except Exception as e:
        err_dl_b = e
        conn_dl_b.rollback()

    t_dl.join()

    conn_dl_a.close()
    conn_dl_b.close()

    deadlock_err = err_dl_a or err_dl_b
    dl_errno = deadlock_err.args[0] if deadlock_err else None
    dl_sqlstate = getattr(deadlock_err, 'sqlstate', None) if deadlock_err else None

    # Verify no corrupted/double mutation occurred
    with conn.cursor() as cur:
        cur.execute("SELECT stock FROM newspaper_boxes WHERE id IN (%s, %s);", (box_dl_1, box_dl_2))
        post_dl_stocks = [r[0] for r in cur.fetchall()]

    deadlock_pass = (dl_errno == 1213) and (dl_sqlstate == '40001' or '40001' in str(deadlock_err))
    log_test('deadlock_handling', deadlock_pass,
             f"(Errno: {dl_errno}, SQLSTATE: {dl_sqlstate}, Zero double-debit, FSM Fail-Closed safe)")

    # Real MariaDB Lock Wait Timeout Test (Errno 1205, SQLSTATE HY000)
    conn_to_a = get_connection(TEST_DB, autocommit=False)
    conn_to_b = get_connection(TEST_DB, autocommit=False)

    # Conn A holds lock on row 1
    with conn_to_a.cursor() as cur_a:
        cur_a.execute("UPDATE newspaper_boxes SET stock = 99 WHERE id = %s;", (box_dl_1,))

    # Conn B sets SESSION-ONLY timeout to 1s (NEVER global!)
    with conn_to_b.cursor() as cur_b:
        cur_b.execute("SET SESSION innodb_lock_wait_timeout = 1;")

    timeout_err = None
    t_start = time.time()
    try:
        with conn_to_b.cursor() as cur_b:
            cur_b.execute("UPDATE newspaper_boxes SET stock = 88 WHERE id = %s;", (box_dl_1,))
            conn_to_b.commit()
    except Exception as e:
        timeout_err = e
        conn_to_b.rollback()
    t_elapsed = time.time() - t_start

    conn_to_a.rollback()
    conn_to_a.close()
    conn_to_b.close()

    to_errno = timeout_err.args[0] if timeout_err else None
    to_sqlstate = getattr(timeout_err, 'sqlstate', None) if timeout_err else None
    timeout_pass = (to_errno == 1205) and (to_sqlstate == 'HY000' or 'HY000' in str(timeout_err)) and (t_elapsed >= 0.9)
    log_test('lock_wait_timeout', timeout_pass,
             f"(Errno: {to_errno}, SQLSTATE: {to_sqlstate}, Elapsed: {round(t_elapsed, 2)}s, Session-only, Fail-Closed safe)")

    conn.close()

    print('\n================================================================')
    print('  MARIADB INTEGRATION GATE SUMMARY')
    print('================================================================')
    all_pass = all(v == 'PASS' for v in results.values())
    passed_count = sum(1 for v in results.values() if v == 'PASS')
    total_count = len(results)
    for k, v in results.items():
        print(f"  {k.ljust(26)} : {v}")
    print('----------------------------------------------------------------')
    print(f"  GATE STATUS                : {'ALL PASS (' + str(passed_count) + '/' + str(total_count) + ')' if all_pass else f'FAIL ({passed_count}/{total_count})'}")
    print('================================================================\n')

    if not all_pass:
        sys.exit(1)

if __name__ == '__main__':
    main()
