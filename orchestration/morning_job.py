"""Datathlon · the morning job (step 10, D-041): everything that runs OUTSIDE Snowflake, in order, in one container.

  docker run ... datathlon-morning-job:1.0.0            # the daily run (started by orchestration/morning_job.sh)
  docker run ... datathlon-morning-job:1.0.0 --check    # only checks the connections (Postgres, Snowflake, GCS)

  1. web shop orders up to yesterday   sources/postgres/generate_orders.py --next-day, once per missing day
  2. web orders Postgres -> BRONZE      ingestion/incremental_orders/load_web_orders.py (MERGE + reconciliation)
  3. till files -> GCS                  sources/tills/till_feed.py --history (only the files not yet in the bucket)
  4. weather + holidays -> GCS          ingestion/api_pull/pull_apis.py (skips a run already in the bucket)
  5. stock files -> GCS                 sources/stock/stock_export.py (after 1 and 3: the stock follows those sales)

At 06:00 the Snowflake task graph loads the files and runs dbt (snowflake/tasks/01_daily_pipeline.sql). Every step is
re-run safe, so running the job twice in a morning adds nothing. The first step that fails stops the job with exit 1;
the task T_CHECK_WEB then fails too, so a missed morning shows up in Snowflake.
"""
import subprocess
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import psycopg2

APP = Path(__file__).resolve().parents[1]
STEPS = [
    ("web orders Postgres -> BRONZE", ["ingestion/incremental_orders/load_web_orders.py"]),
    ("till files -> GCS", ["sources/tills/till_feed.py", "--history"]),
    ("weather + holidays -> GCS", ["ingestion/api_pull/pull_apis.py"]),
    ("stock files -> GCS", ["sources/stock/stock_export.py"]),
]


def log(msg):
    print(f"[{datetime.now(timezone.utc):%Y-%m-%d %H:%M:%S} UTC] {msg}", flush=True)


def run(name, args):
    log(f"START {name}")
    if subprocess.run([sys.executable, *args], cwd=APP).returncode != 0:
        log(f"FAILED {name}: morning job stopped")
        raise SystemExit(1)
    log(f"OK {name}")


def last_order_day():
    with psycopg2.connect() as pg, pg.cursor() as cur:
        cur.execute("SELECT max(order_ts)::date FROM datathlon.orders")
        return cur.fetchone()[0]


def check():
    """Connections only, nothing written: Postgres, Snowflake (service key), Google Cloud Storage (bucket)."""
    sys.path.insert(0, str(APP / "ingestion"))
    from sf_connect import connect
    from google.cloud import storage
    import os
    log(f"Postgres: last web order day {last_order_day()}")
    with connect("morning_job:check") as sf, sf.cursor() as cur:
        cur.execute("SELECT CURRENT_USER(), CURRENT_ROLE(), (SELECT MAX(order_ts)::DATE FROM WEB_ORDERS)")
        log("Snowflake: user %s, role %s, last web order day in BRONZE %s" % cur.fetchone())
    gcs = storage.Client(project=os.environ["GCP_PROJECT_ID"]).bucket(os.environ["GCS_LANDING_BUCKET"])
    log(f"GCS: bucket {gcs.name} readable: {gcs.exists()}")


def main():
    if "--check" in sys.argv:
        check()
        return
    yesterday = date.today() - timedelta(1)
    log(f"Morning job for business day {yesterday}")
    last = last_order_day()
    if last is None:
        log("FAILED web shop database is empty: run generate_orders.py --init once by hand (never in the job)")
        raise SystemExit(1)
    while last < yesterday:
        run(f"web orders for {last + timedelta(1)}", ["sources/postgres/generate_orders.py", "--next-day"])
        last = last_order_day()
    log(f"web orders reach {last}")
    for name, args in STEPS:
        run(name, args)
    log("Morning job done: Snowflake tasks take over at 06:00 Paris")


if __name__ == "__main__":
    main()
