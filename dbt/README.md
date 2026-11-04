# dbt/ · transformations, tests, seed, docs

Bronze → **silver** (clean, typed, one row per business key) and **quarantine** (rejected rows with the reason) → **gold** (UC1, UC2, data quality; complete days only, UTC business day: D-040). Adapted from TD 3.1 `redgrave_dbt` and TD 3.3 `redgrave_kiosk_dbt`. Runs as the service user `DATATHLON_PIPELINE`; the SQL runs in Snowflake.

```bash
dbt/dbt.sh build             # seeds + models + tests (reads the repo's .env)
dbt/dbt.sh source freshness  # is every bronze table loaded in the last 26 h?
dbt/dbt.sh docs generate && dbt/dbt.sh docs serve   # lineage graph
.venv/bin/python dbt/deploy_to_snowflake.py --run build   # production: new version of the project IN Snowflake
```

**Two places, same code (D-043):** on a laptop `dbt/dbt.sh` runs dbt Core (target `dev`, for development). In production the project is deployed into Snowflake as `DATATHLON.OPS.DATATHLON_DBT` (dbt Projects on Snowflake, TD 3.2) and the task `OPS.T_DBT_BUILD` runs `build --target prod` every morning. Our repo is private, so `deploy_to_snowflake.py` uploads the files to a stage (instead of TD 3.2's Git repository object) and names each version after the Git commit; it copies the catalogue CSVs into `seeds/` of the upload.

| Layer | Models | Schema |
| --- | --- | --- |
| seeds | `products` (the required seed), `stores`, `holidays`: read from `sources/catalogue/`, the same files the generators use | SILVER |
| staging | `stg_till_sales` (every till line parsed), `stg_weather_days` (API arrays flattened): views | SILVER |
| silver | `silver_till_sales`, `silver_web_orders`, `silver_web_order_lines`, `silver_stock_daily`, `silver_weather_daily`, `silver_holidays`: tables | SILVER |
| quarantine | `quarantine_till_sales`: rejected or duplicate till lines with `reject_reason` | QUARANTINE |
| gold | `gold_sales_daily` (UC1), `gold_stock_cover_daily` (UC2), `gold_data_quality_daily`: tables, complete days only (macro `last_complete_day`) | GOLD |

**Tests (57):** keys unique / not null, relationships to the seeds, accepted values, and singular tests in `tests/`: every raw till line is in silver or quarantine (fails the build), stock never negative, sold products have stock (UC2 acceptance), prices match the catalogue, real holidays = generator calendar, weather plausible (warnings); gold = silver (revenue and units), one hand-checked day (Belgium, 24 Oct, Cycling), stock alerts rise in the All Saints holidays, quality lines add up.

Every run writes one row per model / test into `GOLD.DBT_RUN_RESULTS` (run evidence).
