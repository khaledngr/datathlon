# Handover to Robin: steps 9 to 12

Written 3 Nov 2026 after step 8, facts refreshed after step 9 (audit D-042). Everything below is on `main`; decisions in [DECISIONS.md](DECISIONS.md) (next: **D-043**), actions in [JOURNAL.md](JOURNAL.md) (next: **#146**). You now own both files: log as you go.

## 1. Where things stand

| Layer | What is there (all data 1 Sep → 2 Nov) | Checked by |
| --- | --- | --- |
| Sources | Postgres web shop (Docker, port 5433), till files, stock CSV + control files, weather + holidays APIs | generator counts, control files |
| GCS `datathlon-landing-513514` | `tills/` 450 files, `stock/` 126, `api/` 6 | — |
| BRONZE | `WEB_ORDERS` 3,479, `WEB_ORDER_LINES` 6,665, `TILL_SALES_RAW` 46,600, `STOCK_SNAPSHOTS` 13,500, `WEATHER_RAW`, `HOLIDAYS_RAW`, `LOAD_RUNS` | reconciliation in every loader |
| SILVER / QUARANTINE | dbt step 8: 6 silver tables, `quarantine_till_sales` (2,235 rows with a reason) | `dbt/dbt.sh build`: 73 / 73 green (57 tests) |
| GOLD | step 9 ✅: `GOLD_SALES_DAILY`, `GOLD_STOCK_COVER_DAILY`, `GOLD_DATA_QUALITY_DAILY` (1 Sep → 2 Nov), `DBT_RUN_RESULTS` (run log) | gold = silver, hand-checked day, web = Postgres (1,019 cells) |

Cost so far: about 0.8 of 20 Snowflake credits this month. Terraform: no drift.

## 2. Run it on your laptop

Your `.env` has `PIPELINE_USER=ROBINCCR` and your own key: every script and `dbt/dbt.sh` run as you with role `DATATHLON_ENGINEER` (on Khaled's laptop they run as `DATATHLON_PIPELINE`). First `git pull`, then `.venv/bin/pip install -r requirements.txt` (dbt is new).

Daily order (the stock reads the web and till sales, so it comes after them): see the README quick start, then `dbt/dbt.sh build`.

## 3. Step 9 · dbt gold ✅ (PR #3, D-040)

Done; kept for the record.


Put the models in `dbt/models/gold/` and add `gold: {+schema: GOLD, +materialized: table}` in `dbt_project.yml`. The analyst role already gets SELECT on every new GOLD table (Terraform future grant).

| Model | Grain and formula | Exclusions / rules |
| --- | --- | --- |
| `gold_sales_daily` (UC1) | day × channel (`store` / `web`) × country × category: units, `SUM(qty × unit_price)` | web: `status = 'paid'` and `not is_test`; click & collect counts as **web**; tills from `silver_till_sales` |
| `gold_stock_cover_daily` (UC3) | day × store × product: `on_hand ÷ average daily units sold over the last 7 days`; `is_alert` when < 3 days | `is_discontinued`; no row = store closed; units sold = till units + paid click & collect units of that store |
| `gold_data_quality_daily` | file day × store: raw lines, quarantine by `reject_reason`, silver lines, `price_fixed_from_cents` | from `stg_till_sales`, `quarantine_till_sales`, `silver_till_sales` |

Rules to decide and log (D-040): **business day = the UTC date** (all generators stamp UTC; simplest and consistent, state it as an assumption) and **gold shows complete days only** (days every source has reached). Tests to add: gold revenue = silver revenue (copy TD 3.1 `assert_gold_matches_silver.sql`), one hand-checked day, alerts exist in the All Saints holidays (expected ~8 % of FR/BE shelves, ~1 % normally).

## 4. Step 10 · Docker + Snowflake Tasks

Open choices, see D-022 points 1 and 2: who starts the jobs that run outside Snowflake (Postgres load, API pull, till and stock generators), and whether dbt moves into Snowflake (dbt Projects on Snowflake, as in TD 3.2, `td3/run_dbt_snowflake.py`) or stays dbt Core. Notes:
- The three `COPY INTO` files (`snowflake/stages/02-04`) can run directly in a Task: no Python needed.
- Creating Tasks needs the account privilege `EXECUTE TASK` for `DATATHLON_ENGINEER`: add the grant in `terraform/roles.tf`, not by hand.
- `run_sql.py` only prints the stock reconciliation: in a scheduled run a mismatch must **fail** the task.
- Containerised job (C3): the web loader in Docker, from the resource pack `06-orchestration-and-docker/docker/python-ingest-job`.

## 5. Step 11 · Streamlit

Read GOLD only, as `DATATHLON_ANALYST` on warehouse `DATATHLON_BI_WH` (both exist). Pages: UC1 sales by day × channel × category with holidays shaded (`silver_holidays` → copy to gold if the analyst must read it); UC3 alerts table; data quality. The story to show: sales and stock alerts jump in the All Saints holidays (FR +74 % web orders, hiking alerts 22 %), Lyon's 24 Oct cents incident caught and fixed.

## 6. Step 12 · Incidents and evidence

1. **Bad till data, live:** `sources/tills/till_feed.py --live --batches 12`, then `snowflake/run_sql.py snowflake/stages/02_tills.sql`, then `dbt/dbt.sh build`: quarantine grows, the accounting test stays green.
2. **Second incident:** a task failure and retry without double counting (step 10), or the broken stock file (load aborted, D-037).

Evidence: `GOLD.DBT_RUN_RESULTS`, `BRONZE.LOAD_RUNS`, `COPY_HISTORY`, query tags `datathlon:*` in query history, screenshots.

## 7. Before the demo (6 Nov): bring all sources to yesterday

Since step 10 (D-043, D-044) this is automatic and no laptop is involved: Cloud Scheduler starts the Cloud Run job `datathlon-morning-job` at 05:30 (web shop Postgres on Cloud SQL), Snowflake Tasks load and run dbt at 06:00. By hand: `gcloud run jobs execute datathlon-morning-job --region europe-west3 --wait` then `EXECUTE TASK DATATHLON.OPS.T_START;`. The manual order below is what the job does.

Run once per missing day, in this order: `generate_orders.py --next-day` (it refuses days after today), the web loader, `till_feed.py --history` (since step 10 it uploads only the files missing from the bucket), `pull_apis.py`, `stock_export.py` (skips days already exported), the stage SQL, `dbt/dbt.sh build`.

## 8. Traps we already hit

- **Terraform while step 10 is unmerged:** schema `OPS` and the `EXECUTE TASK` grant exist in Snowflake but not yet in `main`. A `terraform apply` from `main` would delete them: apply only from the step 10 branch until it is merged.
- **Secondary roles:** our users have `DEFAULT_SECONDARY_ROLES = ALL`, so every role is active at once. Run `USE SECONDARY ROLES NONE` before any access test, or the analyst seems to see everything.
- **Never `--init` Postgres alone:** it resets the web orders, so BRONZE must be emptied and reloaded too, or the loader stops with NOT RECONCILED (on purpose).
- **`COPY INTO` remembers files for 64 days:** a changed file under the same name is loaded again. Never re-send a corrected file with the same name; drop and reload the table instead.
- **A `SELECT $1..$n` in `COPY` does not reject short CSV lines:** keep the `NOT NULL` columns.
- **Snowflake SQL limits met in dbt:** no correlated subquery over `FLATTEN`, no subquery inside `OR`, and `CASE` branches can be evaluated on every row (use `try_` functions).
- Do not modify the TD folders (`td2/`, `td3/`, `td4/`): copy and adapt.
- Changes go through a pull request. Every commit ends with the co-author lines (D-030):
  `Co-authored-by: khaledngr <238613268+khaledngr@users.noreply.github.com>`
  `Co-authored-by: Rudy <235127277+rcausel-a11y@users.noreply.github.com>`
