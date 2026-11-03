"""Datathlon · warehouse stock export (step 7). The store stock system counts every shelf at night and exports one CSV
per day (TD 2 Part A: export -> stage -> COPY INTO), plus a small control file with the expected totals.

  python sources/stock/stock_export.py      # every missing day, 1 Sep -> yesterday, to gs://<bucket>/stock/

Stock follows the REAL sales of the other sources, so UC3's days of cover is consistent with UC1:
  units sold = store till lines (same generator, seed and clean-up rules as silver: duplicates, bad quantities and
  unknown SKUs left out) + paid click & collect web orders picked up in that store (Postgres).
  night count = yesterday's count - units sold + units received.
Replenishment (assumption): the warehouse delivers every Monday and Thursday up to 10 days of the store's average
sales over the last 28 days. That average lags behind a holiday rush, so outdoor products run low in the holidays
(D-033 story: UC3 alerts below 3 days of cover). If a shelf would go below zero, an emergency transfer from another
store arrives the same day (column `emergency`), so the count never goes negative.
Discontinued products keep their last units and are never restocked (UC3 excludes them). Stores closed on Sunday
(France, Belgium) are not counted that night: no rows.
"""
import csv
import math
import os
import sys
from collections import defaultdict
from datetime import date, timedelta
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "sources" / "catalogue"))
sys.path.insert(0, str(REPO / "sources" / "tills"))
from demand import load_holidays, read_csv  # noqa: E402
from till_feed import FIRST_DAY, LOCAL_DIR, bucket, store_day, upload  # noqa: E402  same sales as the till files

DELIVERY_WEEKDAYS = {0, 3}   # Monday, Thursday
TARGET_DAYS = 10             # order up to 10 days of average sales
AVERAGE_WINDOW = 28
DISCONTINUED_LEFT = 6        # units left on the shelf of a discontinued product on 1 Sep
COLUMNS = ["snapshot_date", "store_id", "sku", "on_hand", "received", "emergency", "counted_at"]


def till_units(day, store, products, holidays, stores_by_id, skus):
    """Units sold at the tills, with the clean-up silver will apply (duplicates once, bad quantity / SKU out)."""
    units, seen = defaultdict(int), set()
    for row in store_day(day, store, products, holidays, stores_by_id):
        sid = row.get("sale_id")
        if sid and sid in seen:
            continue
        seen.add(sid)
        qty = row.get("qty")
        if row.get("sku") in skus and isinstance(qty, int) and 0 < qty < 100:
            units[row["sku"]] += qty
    return units


def click_collect_units(last_day):
    """Paid click & collect units per (day, store, sku) from the web shop, test orders excluded."""
    load = defaultdict(int)
    with psycopg2.connect() as pg, pg.cursor() as cur:
        cur.execute("""SELECT o.order_ts::date, o.store_id, l.sku, SUM(l.qty)
            FROM datathlon.orders o JOIN datathlon.order_lines l USING (order_id)
            WHERE o.fulfilment = 'click_collect' AND o.status = 'paid' AND NOT o.is_test AND o.order_ts::date <= %s
            GROUP BY 1, 2, 3""", (last_day,))
        for day, store, sku, qty in cur.fetchall():
            load[(day, store, sku)] += int(qty)
    return load


def simulate(last_day):
    catalogue = read_csv("products.csv")
    active = [p for p in catalogue if p["status"] == "active"]
    skus = {p["sku"] for p in active}
    stores, holidays = read_csv("stores.csv"), load_holidays()
    stores_by_id = {s["store_id"]: s for s in stores}
    cc = click_collect_units(last_day)
    days = [FIRST_DAY + timedelta(d) for d in range((last_day - FIRST_DAY).days + 1)]

    sold = {}  # (day, store, sku) -> units
    for day in days:
        for s in stores:
            units = till_units(day, s, active, holidays, stores_by_id, skus)
            for sku in skus:
                sold[(day, s["store_id"], sku)] = units.get(sku, 0) + cc.get((day, s["store_id"], sku), 0)

    def avg(store, sku, day):  # first weeks: the average of what exists so far (at least the first 7 days)
        window = [d for d in days if day - timedelta(AVERAGE_WINDOW) < d <= day] or days[:7]
        window = window if len(window) >= 7 else days[:7]
        return sum(sold[(d, store, sku)] for d in window) / len(window)

    snapshots = defaultdict(list)
    for s in stores:
        sid, closed_sunday = s["store_id"], s["country"] in {"FR", "BE"}
        for p in catalogue:
            sku, live = p["sku"], p["status"] == "active"
            on_hand = math.ceil(avg(sid, sku, days[6]) * TARGET_DAYS) + 3 if live else DISCONTINUED_LEFT
            for day in days:
                received = 0
                if live and day.weekday() in DELIVERY_WEEKDAYS:
                    received = max(0, math.ceil(avg(sid, sku, day - timedelta(1)) * TARGET_DAYS) + 3 - on_hand)
                units = sold.get((day, sid, sku), 0)
                emergency = max(0, units - on_hand - received)
                on_hand = on_hand + received + emergency - units
                if closed_sunday and day.weekday() == 6:
                    continue  # closed: no night count
                snapshots[day].append({"snapshot_date": day.isoformat(), "store_id": sid, "sku": sku,
                                       "on_hand": on_hand, "received": received, "emergency": emergency,
                                       "counted_at": f"{day + timedelta(1)}T02:00:00Z"})
    return snapshots, sold


def main():
    load_dotenv(REPO / ".env")
    last_day = date.today() - timedelta(1)
    gcs = bucket()
    snapshots, _ = simulate(last_day)
    paths = []
    for day, rows in sorted(snapshots.items()):
        rel = f"stock/{day:%Y/%m/%d}"
        if gcs.blob(f"{rel}/stock_{day:%Y%m%d}.csv").exists():
            continue  # already exported: never re-send a changed snapshot for a day already loaded
        folder = LOCAL_DIR / rel
        folder.mkdir(parents=True, exist_ok=True)
        with open(folder / f"stock_{day:%Y%m%d}.csv", "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=COLUMNS)
            w.writeheader()
            w.writerows(rows)
        with open(folder / f"control_{day:%Y%m%d}.csv", "w", newline="", encoding="utf-8") as fh:
            fh.write("snapshot_date,file_name,row_count,on_hand_total\n"
                     f"{day},stock_{day:%Y%m%d}.csv,{len(rows)},{sum(r['on_hand'] for r in rows)}\n")
        paths += [folder / f"stock_{day:%Y%m%d}.csv", folder / f"control_{day:%Y%m%d}.csv"]
    upload(gcs, paths)
    print(f"Stock: {len(paths) // 2} new days exported ({FIRST_DAY} -> {last_day}), "
          f"uploaded to gs://{os.environ['GCS_LANDING_BUCKET']}/stock/")


if __name__ == "__main__":
    main()
