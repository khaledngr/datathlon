# sources/postgres · the web shop database (step 4, D-032)

Datathlon's web shop writes its orders into its own **PostgreSQL** database (the OLTP source of UC1, web channel).
A generator plays the shop. In production (since D-042) the database is **Postgres 16 on Cloud SQL**, filled and fed by the Cloud Run morning job ([orchestration/](../orchestration/)); the Docker database below is the local copy for development.

| File | What it does | Comes from |
| --- | --- | --- |
| `docker-compose.yml` | Postgres 16.4 on `localhost:5433`, password from your `.env` | resource pack `04-source-databases` (Postgres part) |
| `01_schema.sql` | Schema `datathlon`: `products`, `stores`, `orders`, `order_lines` + the `updated_at` trigger (watermark) | TD 2 `01_create_merch_db.sql`, adapted |
| `generate_orders.py` | `--init`: catalogue + 1 Sep → yesterday (~40 orders/normal day, shaped by holidays, D-033). `--next-day`: one more day + refunds of old orders | new (TD 2 had fixed data) |

Products and stores come from the shared catalogue [sources/catalogue/](../catalogue/): the same codes are used by the tills, the stock export and the dbt seed.

## Run it (from the repo root)

```bash
docker compose --env-file .env -f sources/postgres/docker-compose.yml up -d
.venv/bin/python sources/postgres/generate_orders.py --init
.venv/bin/python sources/postgres/generate_orders.py --next-day
```

Each run ends with a table *generator vs postgres* and `Counts match.` (the "done when" of step 4).

## What is in the data (on purpose)

| | Why |
| --- | --- |
| ~5 % refunded, ~3 % cancelled, 1 test order every 3 days (`is_test`) | UC1 excludes them: the data must contain them to show the exclusion works |
| 30 % click & collect (`store_id` = pick-up store) | omnichannel: ordered online, collected in store |
| 2 discontinued products, never sold | UC2 exclusion |
| `customer_ref` is a code (`C00042`), no name, email or address | GDPR: no personal data in the pipeline (C7) |
| Same seed → same data on every laptop | `--init` twice gives the same 6,665 lines and €348,406.43 (run on 3 Nov) |
| Orders follow each country's holidays ([holidays.csv](../catalogue/holidays.csv)) | the dashboard must show the effect of school holidays (D-033) |

## Shaped for the dashboard (D-033)

Measured on the generated data (France, paid web orders per day): normal 28.7 · back to school 37.9 (+32 %) ·
week before All Saints 37.6 (+31 %) · **All Saints school holidays 49.9 (+74 %)**. Hiking + cycling + swimming go from
48 % to 62 % of units during the holidays. Belgium rises less (half its children per break), Spain stays flat
except its public holidays (12 Oct).

## The watermark (what step 5 relies on)

- A normal `UPDATE` (a refund) moves `updated_at` to **now** (TD 2 trigger), so the next incremental load sees the order again.
- `--next-day` stamps new rows with the **real** time they are written, never a future time. Otherwise an order at 23:00 would push the watermark past refunds made at 13:00, and those refunds would be lost.
- `--init` writes past refunds at their **real past date** (the trigger keeps an `updated_at` set explicitly).
