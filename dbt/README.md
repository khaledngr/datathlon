# dbt/ · transformations, tests, seed, docs

Bronze → **silver** (clean, typed, one row per business key) and **quarantine** (rejected rows with the reason) → gold (step 9). Adapted from TD 3.1 `redgrave_dbt` and TD 3.3 `redgrave_kiosk_dbt`. Runs as the service user `DATATHLON_PIPELINE`; the SQL runs in Snowflake.

```bash
dbt/dbt.sh build             # seeds + models + tests (reads the repo's .env)
dbt/dbt.sh source freshness  # is every bronze table loaded in the last 26 h?
dbt/dbt.sh docs generate && dbt/dbt.sh docs serve   # lineage graph
```

| Layer | Models | Schema |
| --- | --- | --- |
| seeds | `products` (the required seed), `stores`, `holidays`: read from `sources/catalogue/`, the same files the generators use | SILVER |
| staging | `stg_till_sales` (every till line parsed), `stg_weather_days` (API arrays flattened): views | SILVER |
| silver | `silver_till_sales`, `silver_web_orders`, `silver_web_order_lines`, `silver_stock_daily`, `silver_weather_daily`, `silver_holidays`: tables | SILVER |
| quarantine | `quarantine_till_sales`: rejected or duplicate till lines with `reject_reason` | QUARANTINE |
| gold | step 9 | GOLD |

**Tests (55):** keys unique / not null, relationships to the seeds, accepted values, and singular tests in `tests/`: every raw till line is in silver or quarantine (fails the build), stock never negative, sold products have stock (UC3 acceptance), prices match the catalogue, real holidays = generator calendar, weather plausible (warnings).

Every run writes one row per model / test into `GOLD.DBT_RUN_RESULTS` (run evidence).
