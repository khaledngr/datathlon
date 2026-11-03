"""Datathlon · step 5 · incremental load of the web shop (Postgres) into Snowflake BRONZE. Adapted from TD 2
incremental_orders.py: same watermark (MAX(updated_at) already in Snowflake), batch table + MERGE, run log.

Changes from TD 2 (D-034):
  - order LINES are loaded too (UC1 needs revenue by category, TD 2 only kept an order total);
  - 5-minute look-back on the watermark: a row committed in the same second as the last load is not missed,
    and the MERGE removes the overlap, so nothing is counted twice;
  - Postgres is read in one REPEATABLE READ snapshot, so orders and their lines are consistent;
  - runs as the service user DATATHLON_PIPELINE (key pair), not as a person;
  - every run ends with a reconciliation: Postgres counts = BRONZE counts, logged in BRONZE.LOAD_RUNS.

  python ingestion/incremental_orders/load_web_orders.py

Settings from the repo's .env: SNOWFLAKE_ACCOUNT, PIPELINE_USER, PIPELINE_PRIVATE_KEY_PATH, SNOWFLAKE_WAREHOUSE,
SNOWFLAKE_DATABASE, and PGHOST / PGPORT / PGDATABASE / PGUSER / PGPASSWORD.
"""
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
import snowflake.connector
from cryptography.hazmat.primitives import serialization
from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
LOOKBACK = "5 minutes"

DDL = [
    """CREATE TABLE IF NOT EXISTS WEB_ORDERS (
        order_id NUMBER PRIMARY KEY, customer_ref VARCHAR, country VARCHAR, fulfilment VARCHAR, store_id VARCHAR,
        status VARCHAR, is_test BOOLEAN, order_ts TIMESTAMP_TZ, updated_at TIMESTAMP_TZ,
        _loaded_at TIMESTAMP_TZ, _run_id VARCHAR)
        COMMENT = 'Web shop orders, raw copy of Postgres datathlon.orders (incremental MERGE, step 5)'""",
    """CREATE TABLE IF NOT EXISTS WEB_ORDER_LINES (
        order_id NUMBER, line_no NUMBER, sku VARCHAR, qty NUMBER, unit_price_eur NUMBER(8,2),
        _loaded_at TIMESTAMP_TZ, _run_id VARCHAR, PRIMARY KEY (order_id, line_no))
        COMMENT = 'Web shop order lines, raw copy of Postgres datathlon.order_lines (step 5)'""",
    """CREATE TABLE IF NOT EXISTS LOAD_RUNS (
        run_id VARCHAR, source VARCHAR, started_at TIMESTAMP_TZ, finished_at TIMESTAMP_TZ,
        watermark_from TIMESTAMP_TZ, orders_extracted NUMBER, lines_extracted NUMBER,
        orders_inserted NUMBER, orders_updated NUMBER, lines_inserted NUMBER, lines_updated NUMBER,
        source_orders NUMBER, source_lines NUMBER, target_orders NUMBER, target_lines NUMBER, reconciled BOOLEAN)
        COMMENT = 'One row per ingestion run: what was read, what was merged, and whether source = target'""",
]

EXTRACT_ORDERS = f"""
SELECT order_id, customer_ref, country, fulfilment, store_id, status, is_test,
       to_char(order_ts   AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),
       to_char(updated_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"')
FROM datathlon.orders
WHERE updated_at > %s::timestamptz - interval '{LOOKBACK}'
ORDER BY updated_at"""

EXTRACT_LINES = f"""
SELECT l.order_id, l.line_no, l.sku, l.qty, l.unit_price_eur
FROM datathlon.order_lines l
JOIN datathlon.orders o USING (order_id)
WHERE o.updated_at > %s::timestamptz - interval '{LOOKBACK}'"""

MERGE_ORDERS = """
MERGE INTO WEB_ORDERS t
USING (SELECT order_id, customer_ref, country, fulfilment, store_id, status, is_test,
              TO_TIMESTAMP_TZ(order_ts) AS order_ts, TO_TIMESTAMP_TZ(updated_at) AS updated_at FROM ORDERS_BATCH) s
ON t.order_id = s.order_id
WHEN MATCHED AND s.updated_at > t.updated_at THEN UPDATE SET
    customer_ref = s.customer_ref, country = s.country, fulfilment = s.fulfilment, store_id = s.store_id,
    status = s.status, is_test = s.is_test, order_ts = s.order_ts, updated_at = s.updated_at,
    _loaded_at = CURRENT_TIMESTAMP(), _run_id = %(run_id)s
WHEN NOT MATCHED THEN INSERT
    (order_id, customer_ref, country, fulfilment, store_id, status, is_test, order_ts, updated_at, _loaded_at, _run_id)
VALUES (s.order_id, s.customer_ref, s.country, s.fulfilment, s.store_id, s.status, s.is_test, s.order_ts,
        s.updated_at, CURRENT_TIMESTAMP(), %(run_id)s)"""

MERGE_LINES = """
MERGE INTO WEB_ORDER_LINES t
USING LINES_BATCH s
ON t.order_id = s.order_id AND t.line_no = s.line_no
WHEN MATCHED AND (t.sku <> s.sku OR t.qty <> s.qty OR t.unit_price_eur <> s.unit_price_eur) THEN UPDATE SET
    sku = s.sku, qty = s.qty, unit_price_eur = s.unit_price_eur, _loaded_at = CURRENT_TIMESTAMP(), _run_id = %(run_id)s
WHEN NOT MATCHED THEN INSERT (order_id, line_no, sku, qty, unit_price_eur, _loaded_at, _run_id)
VALUES (s.order_id, s.line_no, s.sku, s.qty, s.unit_price_eur, CURRENT_TIMESTAMP(), %(run_id)s)"""


def connect_snowflake():
    key = serialization.load_pem_private_key(Path(os.environ["PIPELINE_PRIVATE_KEY_PATH"]).read_bytes(), password=None)
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["PIPELINE_USER"],
        private_key=key.private_bytes(serialization.Encoding.DER, serialization.PrivateFormat.PKCS8,
                                      serialization.NoEncryption()),
        role="DATATHLON_ENGINEER",
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "DATATHLON_WH"),
        database=os.environ.get("SNOWFLAKE_DATABASE", "DATATHLON"),
        schema="BRONZE",
        session_parameters={"QUERY_TAG": "datathlon:step5:web_orders"},  # cost per job in QUERY_HISTORY
    )


def main():
    load_dotenv(REPO / ".env")
    run_id, started = str(uuid.uuid4()), datetime.now(timezone.utc)
    with connect_snowflake() as sf, sf.cursor() as cur:
        for ddl in DDL:
            cur.execute(ddl)

        # 1. Watermark = the latest change already in Snowflake (TD 2), minus the look-back
        cur.execute("SELECT TO_VARCHAR(MAX(updated_at), 'YYYY-MM-DD\"T\"HH24:MI:SS.FF6TZH:TZM') FROM WEB_ORDERS")
        watermark = cur.fetchone()[0] or "1900-01-01T00:00:00+00:00"
        print(f"Run {run_id[:8]} · watermark {watermark} (minus {LOOKBACK})")

        # 2. Extract only what changed, orders and their lines in ONE consistent snapshot
        pg = psycopg2.connect()
        pg.set_session(isolation_level="REPEATABLE READ", readonly=True)
        with pg, pg.cursor() as pc:
            pc.execute(EXTRACT_ORDERS, (watermark,))
            orders = pc.fetchall()
            pc.execute(EXTRACT_LINES, (watermark,))
            lines = pc.fetchall()
            pc.execute("SELECT (SELECT count(*) FROM datathlon.orders), (SELECT count(*) FROM datathlon.order_lines)")
            source_orders, source_lines = pc.fetchone()
        pg.close()
        print(f"Extracted from Postgres: {len(orders)} orders, {len(lines)} lines")

        # 3. Batch tables + MERGE: re-running never duplicates, a refund updates the existing row
        o_ins = o_upd = l_ins = l_upd = 0
        if orders:
            cur.execute("""CREATE OR REPLACE TEMPORARY TABLE ORDERS_BATCH (order_id NUMBER, customer_ref VARCHAR,
                country VARCHAR, fulfilment VARCHAR, store_id VARCHAR, status VARCHAR, is_test BOOLEAN,
                order_ts VARCHAR, updated_at VARCHAR)""")
            cur.executemany("INSERT INTO ORDERS_BATCH VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)", orders)
            cur.execute(MERGE_ORDERS, {"run_id": run_id})
            o_ins, o_upd = cur.fetchone()
            cur.execute("""CREATE OR REPLACE TEMPORARY TABLE LINES_BATCH (order_id NUMBER, line_no NUMBER,
                sku VARCHAR, qty NUMBER, unit_price_eur NUMBER(8,2))""")
            cur.executemany("INSERT INTO LINES_BATCH VALUES (%s, %s, %s, %s, %s)", lines)
            cur.execute(MERGE_LINES, {"run_id": run_id})
            l_ins, l_upd = cur.fetchone()
        print(f"MERGE orders: {o_ins} inserted, {o_upd} updated · lines: {l_ins} inserted, {l_upd} updated")

        # 4. Reconciliation: source = target, logged (C3 / C6 evidence)
        cur.execute("SELECT (SELECT COUNT(*) FROM WEB_ORDERS), (SELECT COUNT(*) FROM WEB_ORDER_LINES)")
        target_orders, target_lines = cur.fetchone()
        reconciled = (target_orders, target_lines) == (source_orders, source_lines)
        cur.execute(
            "INSERT INTO LOAD_RUNS SELECT %s, 'postgres.web_orders', %s, CURRENT_TIMESTAMP(), TO_TIMESTAMP_TZ(%s), "
            "%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s",
            (run_id, started.isoformat(), watermark, len(orders), len(lines), o_ins, o_upd, l_ins, l_upd,
             source_orders, source_lines, target_orders, target_lines, reconciled))
        print(f"Postgres {source_orders} orders / {source_lines} lines · BRONZE {target_orders} / {target_lines} · "
              f"{'reconciled' if reconciled else 'NOT RECONCILED'}")
        if not reconciled:
            raise SystemExit(1)


if __name__ == "__main__":
    main()
