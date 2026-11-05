# Incidents · how the pipeline behaves when data goes wrong (step 12, D-047)

Three incidents, each runnable live at the defense: the first two rehearsed on the real platform on 4 Nov, the third on clones of the real tables on 5 Nov. Plus the two task failures already seen in step 10. Every number below comes from the run it cites; the IDs can be opened in Snowsight > Monitoring > Query History (query ID) or `GOLD.DBT_RUN_RESULTS` (dbt invocation ID).

## Incident 1 · Bad till data, live

**Story:** the store tills send sales every few seconds with the full set of TD 3.3 defects (duplicates, missing IDs, unknown SKUs, quantities like `"two"` or 999, prices in cents, sales dated 2099, store names spelt five ways, renamed fields).

**Run it (about 2 min):**

```bash
.venv/bin/python snowflake/run_sql.py snowflake/incidents/01_bad_tills_live.sql   # before
.venv/bin/python sources/tills/till_feed.py --live --batches 3                      # 3 files, one every 5 s (~25 lines: defects show, the day's sales barely move)
.venv/bin/python snowflake/run_sql.py snowflake/stages/02_tills.sql                 # GCS -> BRONZE (COPY INTO)
dbt/dbt.sh build                                                                     # BRONZE -> SILVER / QUARANTINE -> GOLD + tests
.venv/bin/python snowflake/run_sql.py snowflake/incidents/01_bad_tills_live.sql   # after
```

**What we expect:** no line rejected at load (the raw line is kept as sent, `VARIANT`), every bad line in `QUARANTINE.QUARANTINE_TILL_SALES` with its reason, the good ones in SILVER, the accounting test green (raw = silver + quarantine), gold unchanged except late sales landing on their real day.

**Rehearsed 4 Nov, 11:06 UTC:**

| | Raw lines | Silver | Quarantine | Unaccounted |
| --- | --- | --- | --- | --- |
| Before | 47,241 | 44,987 | 2,254 (4.8 %) | 0 |
| After 12 live files | 47,345 | 45,071 | 2,274 | **0** |

- 12 live files, 104 lines, each file loaded once (`COPY_HISTORY`: 12 files, 0 refused); `02_tills.sql` run again: 0 new rows.
- Live lines quarantined: **19.2 %** (20 of 104: 6 duplicates, 4 missing sale ID, 4 unknown products, 4 sales dated 2099, 2 bad quantities) against 4.8 % in the history, which carries the defects at a quarter of the live rate (D-014). Store-name variants, prices in cents and odd timestamp formats are **repaired** in silver, not quarantined.
- 4 lines were late events dated 2 Nov: gold revenue for 2 Nov +€183.98 (total €3,017,326.05 → €3,017,509.98). That is the intended handling: a sale counts on the day it happened.
- dbt: 79 / 79 (invocation `e1583a36-648a-4d16-9ba7-a9c181f6c762`), then in Snowflake from commit `ae7689a`: 79 / 79 (`167e4226-2ea3-417c-9254-5d8f4a78002a`).

**Bug found by this incident, fixed:** on the first run 95 of the 104 live lines went to quarantine as `future_timestamp` and the accounting test stayed green. That is right: the test proves nothing is lost, not that the rules are right. Cause: the rule compared the sale time (UTC, no zone) with the load time stored as `TIMESTAMP_TZ` in the account's zone (`America/Los_Angeles`). Snowflake converts the second one to Los Angeles wall time, 8 hours behind, so any sale of the last 8 hours looked "future". The history was never hit: its files are loaded the next morning (0 of its 230 `future_timestamp` lines affected, all dated 2099). Fix: compare in UTC (`convert_timezone('UTC', _loaded_at)`), and a new test `assert_future_sales_really_future` fails if a line flagged future is not after its load time in UTC (it would have returned the 91 wrong lines). Deployed into Snowflake the same morning, so the 06:00 run uses it.

## Incident 2 · A truncated stock file

**Story:** the store stock system's night export stops mid-file: the last line has 4 of its 7 columns. Half a snapshot would be wrong stock, so nothing of that file may be loaded (D-037: `ON_ERROR = ABORT_STATEMENT`, `NOT NULL` columns, control file).

**Run it (30 s):**

```bash
.venv/bin/python snowflake/incidents/02_broken_stock_file.py
```

The script copies the latest real export, keeps 40 lines and cuts line 41 in half, drops it in the bucket as the day 31 Aug (no real export uses that day, so a real day is never blocked), then calls `OPS.LOAD_STOCK()`, the procedure the 06:00 task runs. It always removes the file at the end.

**Rehearsed 4 Nov, 11:16 UTC:**

| Step | Result | Query ID | BRONZE stock |
| --- | --- | --- | --- |
| Before | | | 13,740 rows, 523,005 units, 64 control files |
| Load 1, broken file | **FAILED**: `NULL result in a non-nullable column`, file `stock_20260831.csv`, line 42, column `ON_HAND` | `01c82f42-0001-3537-0000-da6100078076` | unchanged, not even the 40 good lines |
| Load 2, retry (what the task's 2 automatic retries do) | FAILED the same way: a retry does not hide a bad file | `01c82f42-0001-34af-0000-da610007910a` | unchanged |
| File removed (the stock team re-sends the day) | OK: `0 rows loaded, reconciled` | `01c82f42-0001-34f1-0000-da610006e376` | unchanged |

In the scheduled run the same failure makes `T_LOAD_STOCK` fail, dbt is skipped (gold keeps yesterday's figures instead of wrong ones), and after the 2 retries the finalizer e-mails the team. That path was proven in step 10, below.

## Incident 3 · Data deleted or dropped by mistake (Time Travel)

**Story:** someone runs a `DELETE` without its `WHERE` on raw data, or drops a table the dashboard reads. BRONZE is the one layer that cannot be rebuilt (the bucket deletes files after 90 days); silver and gold can (one dbt build).

**Run it (1 min):** [snowflake/incidents/03_time_travel_recovery.sql](../snowflake/incidents/03_time_travel_recovery.sql), block by block in Snowsight.

1. The last 7 days of night stock counts are deleted from `BRONZE.STOCK_SNAPSHOTS`.
2. `SELECT ... AT (TIMESTAMP => $before)` still reads the table as it was.
3. The deleted rows are inserted back from the past. Not a clone swapped in: a clone has no load history, so the next `COPY INTO` would load every stock file twice.
4. `DROP TABLE GOLD.GOLD_HOLIDAYS` (the dashboard breaks), then `UNDROP`: back with its rows, grants and tags; the analyst reads it again.

**Rehearsed 5 Nov** on zero-copy clones of the same tables, so no real data was at risk before the defense: 13,980 rows → 1,500 deleted → 12,480 → 1,500 inserted back → 13,980, units 532,346 before and after (`stock_identical_to_before = TRUE`); the dropped table back with its 16 rows.

**Retention, by design:** every table keeps 1 day of Time Travel. BRONZE tables are permanent (then 7 days of Fail-safe, Snowflake support only); dbt's silver and gold tables are transient (dbt's default): no Fail-safe storage to pay for data one build re-creates.

## Already seen in step 10 (D-043, D-044)

- **Forced task failure, retry, no double counting (3 Nov, journal #157):** a fake stock control line → `T_LOAD_STOCK` fails `STOCK_NOT_RECONCILED`, 2 automatic retries, dbt not run, one e-mail; line removed, `RETRY LAST` → green; BRONZE and gold identical before and after.
- **A real failure in production (4 Nov, 06:00):** the laptop was off, so the web shop load had not run → `T_CHECK_WEB` failed, 2 retries, e-mail to Robin and Khaled; Rudy's unverified address logged in `OPS.PIPELINE_RUNS.email_error` without blocking the others. This is why the morning job moved to Cloud Run (D-044).

## Where the evidence is

| What | Where |
| --- | --- |
| Every graph run, failures, retries, e-mails | `OPS.PIPELINE_RUNS`, [snowflake/tasks/02_task_history.sql](../snowflake/tasks/02_task_history.sql), Snowsight > Monitoring > Task History |
| Every dbt run, node by node | `GOLD.DBT_RUN_RESULTS` (invocation ID, user, status) |
| Every file loaded | `COPY_HISTORY` (query 5 of [01_bad_tills_live.sql](../snowflake/incidents/01_bad_tills_live.sql)), `_file` / `_file_row` on every BRONZE row |
| Who ran what | query tags `datathlon:*` in Query History (`datathlon:sql:02_tills`, `datathlon:dbt`, `datathlon:incident:stock`, ...) |
| Quarantined lines and why | `QUARANTINE.QUARANTINE_TILL_SALES.reject_reason`, Data quality tab of the dashboard (from the day after, when the day is complete) |

## Screenshots (4 Nov, in [evidence/](evidence/))

| File | What it shows |
| --- | --- |
| [incident2_terminal.png](evidence/incident2_terminal.png) | Incident 2 run: load fails twice (file, line 42, `ON_HAND`), file removed, load OK, BRONZE unchanged (output of the 13:21 run, query IDs inside) |
| [dbt_lineage.png](evidence/dbt_lineage.png) | dbt lineage without tests: bronze sources and seeds → staging → silver / quarantine → the 4 gold tables |
| [dbt_gold_stock_columns.png](evidence/dbt_gold_stock_columns.png) | `gold_stock_cover_daily` in dbt docs: every column described, tests per column |
