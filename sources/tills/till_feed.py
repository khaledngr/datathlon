"""Datathlon · store till feed (step 6). Adapted from TD 3.3 kiosk_sales_generator.py: same NDJSON files and the
same deliberate defects, now for 8 Datathlon stores, the shared catalogue and the shared demand rules (D-033).

  python sources/tills/till_feed.py --history            # one file per store per day, 1 Sep -> yesterday
  python sources/tills/till_feed.py --live               # today: a batch every 5 s from all stores (Ctrl+C)
  python sources/tills/till_feed.py --live --batches 12  # stop after 12 batches (the live incident demo)

Files go to gs://<GCS_LANDING_BUCKET>/tills/YYYY/MM/DD/ (a copy stays in data/landing/, git-ignored), then Snowflake
loads them with COPY INTO (snowflake/stages/02_tills.sql). One row = one product line scanned at a till.

Defects (TD 3.3 list): the history has them at a quarter of the live rate, plus one real-looking incident:
on 24 Oct the Lyon store's tills send prices in cents after a software update. --live uses the full TD 3.3 rates.
No personal data: the TD 3.3 customer e-mail is replaced by an optional loyalty card code (GDPR).
"""
import argparse
import json
import os
import random
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "sources" / "catalogue"))
from demand import demand, load_holidays, product_weights, read_csv  # noqa: E402  shared rules (D-033)

FIRST_DAY = date(2026, 9, 1)
SEED = 6
LINES_PER_STORE_DAY = 70                       # normal weekday, before the demand factor
STORE_SIZE = {"PAR-01": 1.4, "LYO-01": 1.1, "BCN-01": 1.1, "MAD-01": 1.1}  # others 1.0
PAYMENTS = {"card": 55, "contactless": 35, "cash": 10}
LOCAL_DIR = REPO / "data" / "landing"
LYON_CENTS_DAY = date(2026, 10, 24)            # the historical incident

DEFECTS = [  # (name, probability per row at the live rate) - from TD 3.3
    ("duplicate", 0.06),        # the same sale sent twice (till retried after a timeout)
    ("missing_id", 0.03),       # sale_id null or absent
    ("store_variant", 0.20),    # "par-01 ", "PAR01", "Paris La Defense"
    ("bad_qty", 0.06),          # 0, negative, "two", 999
    ("price_format", 0.15),     # "€39,99", "39,99", 3999 (cents)
    ("ts_format", 0.15),        # "26/10/2026 15:04", epoch millis
    ("future_ts", 0.02),        # year 2099
    ("late_event", 0.04),       # 2 days old
    ("unknown_sku", 0.04),      # "DTH-XXX-999", lower-case sku, blank
    ("payment_variant", 0.20),  # "CARD", "Card ", "apple pay", null
    ("schema_drift", 0.05),     # unitPrice instead of unit_price, extra promo_code
]


def clean_row(rng, store, sold_at, products, weights):
    p = rng.choices(products, weights)[0]
    return {
        "sale_id": str(uuid.UUID(int=rng.getrandbits(128))),
        "store_id": store["store_id"],
        "till": f"T{rng.randint(1, 6):02d}",
        "sold_at": sold_at.isoformat(timespec="seconds"),
        "sku": p["sku"],
        "qty": rng.choices([1, 2, 3, 4], [70, 20, 7, 3])[0],
        "unit_price": float(p["price_eur"]),
        "payment": rng.choices(list(PAYMENTS), list(PAYMENTS.values()))[0],
        "loyalty_id": f"L{rng.randint(1, 999999):06d}" if rng.random() < 0.5 else None,
    }


def damage(rng, row, scale, stores_by_id):
    """Return one or more (possibly corrupted) copies of the row (TD 3.3 logic)."""
    resend = False
    sold_at = datetime.fromisoformat(row["sold_at"])
    for name, p in DEFECTS:
        if rng.random() >= p * scale:
            continue
        if name == "duplicate":
            resend = True
        elif name == "missing_id":
            if rng.random() < 0.5:
                row["sale_id"] = None
            else:
                row.pop("sale_id", None)
        elif name == "store_variant":
            s = row["store_id"]
            row["store_id"] = rng.choice([s.lower() + " ", s.replace("-", ""), stores_by_id[s]["name"].replace("Datathlon ", "")])
        elif name == "bad_qty":
            row["qty"] = rng.choice([0, -1, -2, "two", "1 ", 999])
        elif name == "price_format":
            price = row.pop("unit_price", 10.0)
            row["unit_price"] = rng.choice([f"€{price:.2f}".replace(".", ","), f"{price:.2f}".replace(".", ","),
                                            int(round(price * 100))])
        elif name == "ts_format":
            row["sold_at"] = rng.choice([sold_at.strftime("%d/%m/%Y %H:%M"), int(sold_at.timestamp() * 1000)])
        elif name == "future_ts":
            row["sold_at"] = sold_at.replace(year=2099).isoformat(timespec="seconds")
        elif name == "late_event":
            row["sold_at"] = (sold_at - timedelta(days=2)).isoformat(timespec="seconds")
        elif name == "unknown_sku":
            row["sku"] = rng.choice(["DTH-XXX-999", row["sku"].lower(), ""])
        elif name == "payment_variant":
            row["payment"] = rng.choice(["CARD", "Card ", "apple pay", None, "Contactless"])
        elif name == "schema_drift":
            if "unit_price" in row:
                row["unitPrice"] = row.pop("unit_price")
            row["promo_code"] = rng.choice(["AUTUMN10", None, "CLUB"])
    return [row, dict(row)] if resend else [row]


def store_day(day, store, products, holidays, stores_by_id):
    """All till rows of one store for one day, identical on every run (seed = day + store)."""
    rng = random.Random(f"{SEED}-{day.isoformat()}-{store['store_id']}")
    factor, boost = demand(day, store["country"], holidays, channel="store")
    if factor == 0:
        return []  # closed (Sunday in France and Belgium)
    n = max(0, round(rng.gauss(LINES_PER_STORE_DAY * factor * STORE_SIZE.get(store["store_id"], 1.0), 6)))
    weights = product_weights(products, boost)
    opening = datetime(day.year, day.month, day.day, 8, tzinfo=timezone.utc)   # 09:00-20:00 local time
    rows = []
    for sold_at in sorted(opening + timedelta(seconds=rng.randint(0, 11 * 3600)) for _ in range(n)):
        row = clean_row(rng, store, sold_at, products, weights)
        if day == LYON_CENTS_DAY and store["store_id"] == "LYO-01":
            row["unit_price"] = int(round(row["unit_price"] * 100))  # the incident: cents instead of euros
        rows += damage(rng, row, 0.25, stores_by_id)
    return rows


def write_local(rel_path, rows):
    path = LOCAL_DIR / rel_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(r, ensure_ascii=False) + "\n" for r in rows), encoding="utf-8")
    return path


def bucket():
    from google.cloud import storage  # Google sign-in: gcloud auth application-default login
    return storage.Client(project=os.environ["GCP_PROJECT_ID"]).bucket(os.environ["GCS_LANDING_BUCKET"])


def upload(gcs, paths):
    def one(path):
        gcs.blob(str(path.relative_to(LOCAL_DIR))).upload_from_filename(str(path), content_type="application/x-ndjson")
    with ThreadPoolExecutor(max_workers=16) as pool:
        list(pool.map(one, paths))


def history(products, stores, holidays):
    stores_by_id = {s["store_id"]: s for s in stores}
    paths, rows_total = [], 0
    for d in range((date.today() - FIRST_DAY).days):
        day = FIRST_DAY + timedelta(d)
        for store in stores:
            rows = store_day(day, store, products, holidays, stores_by_id)
            if rows:  # closed on Sunday (France, Belgium): no file
                paths.append(write_local(f"tills/{day:%Y/%m/%d}/{store['store_id']}_{day:%Y%m%d}.json", rows))
                rows_total += len(rows)
    upload(bucket(), paths)
    print(f"History: {len(paths)} files, {rows_total} rows, {FIRST_DAY} -> {date.today() - timedelta(1)}, "
          f"uploaded to gs://{os.environ['GCS_LANDING_BUCKET']}/tills/")


def live(products, stores, interval, batches, rows_per_batch):
    """TD 3.3 live mode: every few seconds a small batch from random stores, full defect rate."""
    rng, gcs = random.Random(), bucket()
    stores_by_id = {s["store_id"]: s for s in stores}
    weights = product_weights(products, {})
    n = 0
    print(f"Till feed live -> gs://{os.environ['GCS_LANDING_BUCKET']}/tills/ every {interval}s, Ctrl+C to stop")
    try:
        while batches == 0 or n < batches:
            n += 1
            now = datetime.now(timezone.utc)
            rows = []
            for _ in range(rows_per_batch):
                rows += damage(rng, clean_row(rng, rng.choice(stores), now, products, weights), 1.0, stores_by_id)
            path = write_local(f"tills/{now:%Y/%m/%d}/live_{now:%Y%m%dT%H%M%S}_{n:04d}.json", rows)
            upload(gcs, [path])
            print(f"[{now:%H:%M:%S}] batch {n}: {len(rows)} rows -> {path.name}")
            if batches == 0 or n < batches:
                time.sleep(interval)
    except KeyboardInterrupt:
        print("\nStopped.")


def main():
    ap = argparse.ArgumentParser(description="Datathlon store till feed (bad data on purpose, TD 3.3).")
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--history", action="store_true", help="one file per store per day, 1 Sep -> yesterday")
    mode.add_argument("--live", action="store_true", help="a batch every --interval seconds (today)")
    ap.add_argument("--interval", type=float, default=5.0)
    ap.add_argument("--batches", type=int, default=0, help="live: stop after N batches (0 = until Ctrl+C)")
    ap.add_argument("--rows", type=int, default=8, help="live: sales per batch before defects")
    a = ap.parse_args()
    load_dotenv(REPO / ".env")
    products = [p for p in read_csv("products.csv") if p["status"] == "active"]
    stores = read_csv("stores.csv")
    if a.history:
        history(products, stores, load_holidays())
    else:
        live(products, stores, a.interval, a.batches, a.rows)


if __name__ == "__main__":
    main()
