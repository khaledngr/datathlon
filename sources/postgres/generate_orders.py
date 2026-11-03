"""Datathlon · web shop order generator (step 4). Plays the live web shop writing into its own Postgres database.

Data style from TD 2 (orders + order lines, updated_at as the watermark); loading style from the resource pack
04-source-databases (psycopg2, standard PG* settings). The data is synthetic and deterministic (fixed seed per day).

  python sources/postgres/generate_orders.py --init        # catalogue + every day from 1 Sep 2026 to yesterday
  python sources/postgres/generate_orders.py --next-day    # one more day of orders + a few refunds of old orders

--next-day refunds old orders with an UPDATE: the trigger moves their updated_at, so the incremental load (step 5)
must pick them up again and MERGE them, not duplicate them. That is the point of the demo.
The data is shaped for the dashboard (D-033): demand follows each country's holidays (sources/catalogue/holidays.csv,
same dates as the holiday API the pipeline loads), so the BI can show the effect of school holidays:
  school holidays +60 % (x share of the country), the week before +30 % (families get ready), public holiday +40 %,
  back to school (1-14 Sep) +30 %; during school holidays outdoor categories sell more, at back to school team sports
  and swimming (club sign-ups). Weekends: Saturday x1.6, Sunday x1.3.
Each run prints what it wrote, then counts the rows in Postgres: both must match ("done when" of step 4).
Settings: PGHOST, PGPORT, PGDATABASE, PGUSER, PGPASSWORD from the repo's .env.
"""
import argparse
import random
import sys
from datetime import date, datetime, time, timedelta, timezone
from pathlib import Path

import psycopg2
from dotenv import load_dotenv

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "sources" / "catalogue"))
from demand import demand, load_holidays, product_weights, read_csv  # noqa: E402  shared rules (D-033)

FIRST_DAY = date(2026, 9, 1)  # a "normal" September baseline before the autumn holidays
SEED = 2026

ORDERS_PER_DAY = {"FR": 28, "BE": 6, "ES": 6}  # normal weekday, by delivery country (70 / 15 / 15 %)
CLICK_COLLECT_SHARE = 0.30   # picked up in a store
CANCELLED_SHARE = 0.03       # cancelled before payment went through
REFUND_SHARE = 0.05          # refunded a few days later
TEST_ORDERS_EVERY = 3        # one QA test order every 3 days


def load_catalogue(cur):
    """Products and stores from the shared catalogue (same codes as the tills, stock and dbt seed)."""
    products, stores = read_csv("products.csv"), read_csv("stores.csv")
    cur.executemany(
        "INSERT INTO datathlon.products VALUES (%(sku)s, %(name)s, %(category)s, %(price_eur)s, %(status)s) "
        "ON CONFLICT (sku) DO UPDATE SET name = EXCLUDED.name, category = EXCLUDED.category, "
        "price_eur = EXCLUDED.price_eur, status = EXCLUDED.status", products)
    cur.executemany(
        "INSERT INTO datathlon.stores VALUES (%(store_id)s, %(name)s, %(city)s, %(country)s, %(latitude)s, %(longitude)s) "
        "ON CONFLICT (store_id) DO NOTHING", stores)
    return products, stores


def day_orders(day, first_order_id, products, stores, holidays):
    """All orders of one day, the same every time for the same day (seed = SEED + day)."""
    rng = random.Random(SEED * 1000 + day.toordinal())
    sellable = [p for p in products if p["status"] == "active"]

    plan = []  # (country, product weights) for each order of the day
    for country, base in ORDERS_PER_DAY.items():
        factor, boost = demand(day, country, holidays)
        weights = product_weights(sellable, boost)
        n = max(0, round(rng.gauss(base * factor, base * 0.12)))
        plan += [(country, weights)] * n
    rng.shuffle(plan)

    orders, lines = [], []
    for i, (country, weights) in enumerate(plan):
        order_id = first_order_id + i
        ts = datetime.combine(day, time(7), timezone.utc) + timedelta(seconds=rng.randint(0, 16 * 3600))
        click_collect = rng.random() < CLICK_COLLECT_SHARE
        orders.append({
            "order_id": order_id,
            "customer_ref": f"C{rng.randint(1, 5000):05d}",
            "country": country,
            "fulfilment": "click_collect" if click_collect else "home_delivery",
            "store_id": rng.choice([s for s in stores if s["country"] == country])["store_id"] if click_collect else None,
            "status": "cancelled" if rng.random() < CANCELLED_SHARE else "paid",
            "is_test": False,
            "order_ts": ts,
            "updated_at": ts,
        })
        for line_no, p in enumerate(rng.sample(rng.choices(sellable, weights, k=6), k=rng.randint(1, 3)), start=1):
            lines.append({"order_id": order_id, "line_no": line_no, "sku": p["sku"],
                          "qty": rng.choices([1, 2, 3], [80, 15, 5])[0], "unit_price_eur": p["price_eur"]})
    if day.toordinal() % TEST_ORDERS_EVERY == 0:
        test_id = first_order_id + len(plan)
        ts = datetime.combine(day, time(6, 30), timezone.utc)
        orders.append({"order_id": test_id, "customer_ref": "TEST-QA", "country": "FR", "fulfilment": "home_delivery",
                       "store_id": None, "status": "paid", "is_test": True, "order_ts": ts, "updated_at": ts})
        lines.append({"order_id": test_id, "line_no": 1, "sku": sellable[0]["sku"], "qty": 1,
                      "unit_price_eur": sellable[0]["price_eur"]})
    # the weighted draw can pick the same sku twice in one order: keep one line per sku, then renumber
    seen, unique_lines = set(), []
    for l in lines:
        if (l["order_id"], l["sku"]) not in seen:
            seen.add((l["order_id"], l["sku"]))
            unique_lines.append(l)
    for o in orders:
        own = [l for l in unique_lines if l["order_id"] == o["order_id"]]
        for k, l in enumerate(own, start=1):
            l["line_no"] = k
    return orders, unique_lines


def insert_day(cur, day, products, stores, holidays, simulate_time):
    cur.execute("SELECT coalesce(max(order_id), 0) + 1 FROM datathlon.orders")
    orders, lines = day_orders(day, cur.fetchone()[0], products, stores, holidays)
    if not simulate_time:
        # Live mode: updated_at = when the row is really written, never in the future. Otherwise an order
        # stamped 23:00 would push the step 5 watermark past refunds stamped "now", and they would be skipped.
        written_at = datetime.now(timezone.utc)
        for o in orders:
            o["updated_at"] = written_at
    cur.executemany(
        "INSERT INTO datathlon.orders VALUES (%(order_id)s, %(customer_ref)s, %(country)s, %(fulfilment)s, %(store_id)s, "
        "%(status)s, %(is_test)s, %(order_ts)s, %(updated_at)s)", orders)
    cur.executemany(
        "INSERT INTO datathlon.order_lines VALUES (%(order_id)s, %(line_no)s, %(sku)s, %(qty)s, %(unit_price_eur)s)", lines)
    return len(orders), len(lines)


def refund_some(cur, day, simulate_time):
    """Refund ~5 % of the paid orders placed 2 to 14 days before `day`.

    --init writes the refund time itself (history); --next-day lets the TD 2 trigger stamp updated_at = now,
    exactly like the real shop would, so the watermark sees the change.
    """
    rng = random.Random(SEED * 7 + day.toordinal())
    cur.execute(
        "SELECT order_id FROM datathlon.orders WHERE status = 'paid' AND NOT is_test "
        "AND order_ts::date BETWEEN %s AND %s ORDER BY order_id", (day - timedelta(days=14), day - timedelta(days=2)))
    candidates = [r[0] for r in cur.fetchall()]
    picked = rng.sample(candidates, k=min(len(candidates), round(sum(ORDERS_PER_DAY.values()) * REFUND_SHARE)))
    for order_id in picked:
        if simulate_time:  # history: the refund happened at noon that day (the trigger keeps an explicit updated_at)
            cur.execute("UPDATE datathlon.orders SET status = 'refunded', updated_at = %s WHERE order_id = %s",
                        (datetime.combine(day, time(12), timezone.utc), order_id))
        else:              # live: the trigger stamps updated_at = now, like the real shop
            cur.execute("UPDATE datathlon.orders SET status = 'refunded' WHERE order_id = %s", (order_id,))
    return len(picked)


def counts(cur):
    cur.execute("""
        SELECT (SELECT count(*) FROM datathlon.products), (SELECT count(*) FROM datathlon.stores),
               (SELECT count(*) FROM datathlon.orders), (SELECT count(*) FROM datathlon.order_lines),
               (SELECT count(*) FROM datathlon.orders WHERE status = 'refunded')""")
    return dict(zip(["products", "stores", "orders", "order_lines", "refunded"], cur.fetchone()))


def main():
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--init", action="store_true", help="empty the tables, load the catalogue and the history")
    mode.add_argument("--next-day", action="store_true", help="add the day after the last one + refunds")
    a = ap.parse_args()
    load_dotenv(REPO / ".env")

    with psycopg2.connect() as con, con.cursor() as cur:
        written = {"orders": 0, "order_lines": 0, "refunded": 0}
        if a.init:
            cur.execute("TRUNCATE datathlon.order_lines, datathlon.orders, datathlon.products, datathlon.stores")
            days = [FIRST_DAY + timedelta(d) for d in range((date.today() - FIRST_DAY).days)]  # up to yesterday
        else:
            cur.execute("SELECT max(order_ts)::date FROM datathlon.orders")
            last = cur.fetchone()[0]
            if last is None:
                raise SystemExit("No orders yet: run --init first.")
            days = [last + timedelta(1)]
        products, stores = load_catalogue(cur)
        holidays = load_holidays()
        before = counts(cur)
        for day in days:
            o, l = insert_day(cur, day, products, stores, holidays, simulate_time=a.init)
            written["orders"] += o
            written["order_lines"] += l
            written["refunded"] += refund_some(cur, day, simulate_time=a.init)
        after = counts(cur)

    print(f"Days generated: {days[0]} -> {days[-1]} ({len(days)})")
    print(f"{'':12} {'generator':>10} {'postgres':>10}")
    ok = True
    for k in ("orders", "order_lines", "refunded"):
        in_db = after[k] - before[k]
        ok &= in_db == written[k]
        print(f"{k:12} {written[k]:>10} {in_db:>10}")
    print(f"{'products':12} {len(products):>10} {after['products']:>10}")
    print(f"{'stores':12} {len(stores):>10} {after['stores']:>10}")
    ok &= after["products"] == len(products) and after["stores"] == len(stores)
    print("Counts match." if ok else "MISMATCH between generator and Postgres!")
    if not ok:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
