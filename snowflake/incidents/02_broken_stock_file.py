"""Datathlon · incident 2: the stock system sends a truncated export (step 12). From the repo root:

  .venv/bin/python snowflake/incidents/02_broken_stock_file.py

Takes the latest real stock export from the bucket, keeps its first 40 lines and cuts line 41 in half (the export
stopped mid-file), and drops it in the bucket as the day 31 Aug: a day no export ever writes (the data starts on 1 Sep),
so it cannot block a real day. Then calls OPS.LOAD_STOCK, the procedure the 06:00 task runs:
  1. load fails (ON_ERROR = ABORT_STATEMENT + NOT NULL columns, D-037): nothing loaded, not even the 40 good lines;
  2. retry with the file still there fails the same way (what the task's 2 automatic retries do);
  3. the broken file is removed (the stock team re-sends the day), load passes, BRONZE unchanged.
BRONZE counts are printed between every step; the query IDs are the evidence in Snowsight > Query History.
"""
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "ingestion"))
from sf_connect import connect  # noqa: E402

load_dotenv(REPO / ".env")
COUNTS = """SELECT (SELECT COUNT(*) FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS), (SELECT SUM(on_hand) FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS),
                   (SELECT COUNT(*) FROM DATATHLON.BRONZE.STOCK_CONTROL), (SELECT MAX(snapshot_date) FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS)"""


def broken_export(gcs):
    latest = max((b for b in gcs.client.list_blobs(gcs, prefix="stock/") if "/stock_" in b.name), key=lambda b: b.name)
    day = latest.name[-12:-4]
    lines = [line.replace(f"{day[:4]}-{day[4:6]}-{day[6:]}", "2026-08-31") for line in latest.download_as_text().splitlines()[:41]]
    lines.append(lines[-1][: len(lines[-1]) // 2])  # the export stopped mid-line
    print(f"Truncated copy of {latest.name}: 40 good lines + half a line")
    return "\n".join(lines) + "\n"


def main():
    from google.cloud import storage  # Google sign-in: gcloud auth application-default login
    gcs = storage.Client(project=os.environ["GCP_PROJECT_ID"]).bucket(os.environ["GCS_LANDING_BUCKET"])
    blob = gcs.blob("stock/2026/08/31/stock_20260831.csv")
    with connect("ingestion:incident_stock", schema="OPS") as sf, sf.cursor() as c:
        def counts(label):
            c.execute(COUNTS)
            rows, units, controls, last = c.fetchone()
            print(f"  BRONZE {label:<22} {rows:,} rows, {units:,} units, {controls} control files, last day {last}")

        def load(label):
            try:
                c.execute("CALL DATATHLON.OPS.LOAD_STOCK()")
                print(f"{label}: OK -> {c.fetchone()[0]} (query {c.sfqid})")
            except Exception as e:  # the failure IS the demo
                print(f"{label}: FAILED (query {c.sfqid})\n    " + "\n    ".join(str(e).splitlines()[:3]))

        counts("before")
        blob.upload_from_string(broken_export(gcs), content_type="text/csv")
        print(f"Dropped in gs://{gcs.name}/{blob.name}")
        try:
            load("Load 1, broken file")
            counts("after load 1")
            load("Load 2, retry")
            counts("after load 2")
        finally:  # left in the bucket, the file would fail every morning run until removed
            blob.delete()
        print("Broken file removed (the stock team re-sends the day)")
        load("Load 3, after the fix")
        counts("after the fix")


if __name__ == "__main__":
    main()
