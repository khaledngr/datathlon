-- =====================================================================================================================
-- Datathlon · the pipeline in production, from the files to the dashboard (screen recording, docs/DEMO_VIDEO.md).
-- Paste into one Snowsight worksheet. Run one block at a time (select it, Ctrl/Cmd + Enter), in order.
-- Read-only except block 3, which starts the real 06:00 task graph now.
-- =====================================================================================================================

-- ---------- 0. Who I am, and the moment the recording starts ----------
USE ROLE DATATHLON_ENGINEER;
USE SECONDARY ROLES NONE;          -- one role at a time: what this role sees, nothing more
USE WAREHOUSE DATATHLON_WH;
SET demo_start = CURRENT_TIMESTAMP();
SELECT CURRENT_ROLE() AS role, CONVERT_TIMEZONE('Europe/Paris', $demo_start)::TIMESTAMP_NTZ AS recording_starts_paris;

-- ---------- 1. Before: every raw till line is in SILVER or in QUARANTINE, exactly once ----------
SELECT (SELECT COUNT(*) FROM DATATHLON.BRONZE.TILL_SALES_RAW)            AS raw_lines,
       (SELECT COUNT(*) FROM DATATHLON.SILVER.SILVER_TILL_SALES)         AS silver_lines,
       (SELECT COUNT(*) FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES) AS quarantined_lines,
       raw_lines - silver_lines - quarantined_lines                      AS unaccounted;

-- ---------- 2. (after the live feed in the terminal) the new files waiting in the landing bucket ----------
LIST @DATATHLON.BRONZE.LANDING/tills/ PATTERN = '.*live_.*';

-- ---------- 3. Start the production graph now (what runs every day at 06:00 Paris) ----------
-- Then open Monitoring > Task History > T_START (graph view) and watch the tasks turn green (about 1 minute).
EXECUTE TASK DATATHLON.OPS.T_START;

-- The same, as a table: every task of this run
SELECT name, state, CONVERT_TIMEZONE('Europe/Paris', query_start_time)::TIME AS started,
       DATEDIFF('second', query_start_time, completed_time) AS seconds, return_value, error_message
FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TASK_HISTORY(SCHEDULED_TIME_RANGE_START => $demo_start))
WHERE database_name = 'DATATHLON'
ORDER BY query_start_time;

-- ---------- 4. BRONZE: every line exactly as the tills sent it, with its file and line number ----------
SELECT _file, _file_row, CONVERT_TIMEZONE('Europe/Paris', _loaded_at)::TIMESTAMP_NTZ AS loaded_paris, raw
FROM DATATHLON.BRONZE.TILL_SALES_RAW
WHERE _loaded_at >= $demo_start
ORDER BY _file, _file_row;

-- ---------- 5. A bad line never reaches the numbers: QUARANTINE, with the reason and the raw line ----------
SELECT q.reject_reason, q.store_raw, q.sku, q.qty, q.unit_price_raw, q.sold_at_utc, r.raw AS line_as_sent
FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES q
JOIN DATATHLON.BRONZE.TILL_SALES_RAW r USING (_file, _file_row)
WHERE r._loaded_at >= $demo_start
ORDER BY q.reject_reason;

SELECT q.reject_reason, COUNT(*) AS lines
FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES q
JOIN DATATHLON.BRONZE.TILL_SALES_RAW r USING (_file, _file_row)
WHERE r._loaded_at >= $demo_start
GROUP BY 1 ORDER BY lines DESC;

-- ---------- 6. Lines that can be fixed are repaired in SILVER (store name, price in cents, quantity as text) ----------
SELECT r.raw AS line_as_sent, s.store_id, s.sku, s.category, s.qty, s.unit_price_eur, s.price_fixed_from_cents,
       s.revenue_eur, s.sold_at_utc
FROM DATATHLON.SILVER.SILVER_TILL_SALES s
JOIN DATATHLON.BRONZE.TILL_SALES_RAW r USING (_file, _file_row)
WHERE r._loaded_at >= $demo_start
ORDER BY (r.raw:store_id::STRING IS NOT DISTINCT FROM s.store_id AND NOT s.price_fixed_from_cents
          AND r.raw:qty::STRING = s.qty::STRING), s.store_id;

-- ---------- 7. Nothing lost: this run's lines, and every line ever ----------
SELECT COUNT(*) AS new_raw_lines, COUNT(s._file) AS to_silver, COUNT(q._file) AS to_quarantine,
       COUNT(*) - COUNT(s._file) - COUNT(q._file) AS unaccounted,
       ROUND(100 * COUNT(q._file) / NULLIF(COUNT(*), 0), 1) AS pct_quarantined
FROM DATATHLON.BRONZE.TILL_SALES_RAW r
LEFT JOIN DATATHLON.SILVER.SILVER_TILL_SALES s USING (_file, _file_row)
LEFT JOIN DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES q USING (_file, _file_row)
WHERE r._loaded_at >= $demo_start;

SELECT (SELECT COUNT(*) FROM DATATHLON.BRONZE.TILL_SALES_RAW)            AS raw_lines,
       (SELECT COUNT(*) FROM DATATHLON.SILVER.SILVER_TILL_SALES)         AS silver_lines,
       (SELECT COUNT(*) FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES) AS quarantined_lines,
       raw_lines - silver_lines - quarantined_lines                      AS unaccounted;

-- ---------- 8. dbt inside Snowflake: every model and test of this run ----------
SELECT resource_type, status, COUNT(*) AS nodes, ROUND(SUM(execution_seconds), 1) AS seconds
FROM DATATHLON.GOLD.DBT_RUN_RESULTS
WHERE run_at >= $demo_start
GROUP BY 1, 2 ORDER BY 1, 2;

SELECT node, status, failures
FROM DATATHLON.GOLD.DBT_RUN_RESULTS
WHERE run_at >= $demo_start AND resource_type = 'test'
ORDER BY node;

-- ---------- 9. GOLD: one table per business decision (complete days only: today arrives tomorrow at 06:00) ----------
SELECT sales_date, channel, ROUND(SUM(revenue_eur), 2) AS revenue_eur, SUM(units) AS units
FROM DATATHLON.GOLD.GOLD_SALES_DAILY
WHERE sales_date >= CURRENT_DATE() - 7
GROUP BY 1, 2 ORDER BY 1 DESC, 2;

SELECT snapshot_date, COUNT_IF(is_alert) AS shelves_under_3_days, COUNT(*) AS shelves
FROM DATATHLON.GOLD.GOLD_STOCK_COVER_DAILY
GROUP BY 1 ORDER BY 1 DESC LIMIT 14;

-- ---------- 10. The run log: what the 06:00 run writes every day (and e-mails if a task failed) ----------
SELECT CONVERT_TIMEZONE('Europe/Paris', finished_at)::TIMESTAMP_NTZ AS finished_paris, tasks_succeeded, tasks_failed,
       retries, failed_tasks, first_error
FROM DATATHLON.OPS.PIPELINE_RUNS
ORDER BY finished_at DESC LIMIT 3;

-- ---------- 11. Governance: personal data masked, every credit has an owner ----------
SELECT order_id, customer_ref FROM DATATHLON.BRONZE.WEB_ORDERS ORDER BY order_id LIMIT 3;   -- engineer: pseudonyms

SELECT cost_center, owner, ROUND(SUM(total_credits), 3) AS credits, ROUND(SUM(total_usd), 2) AS usd
FROM DATATHLON.GOLD.GOLD_COST_SHOWBACK_DAILY
GROUP BY 1, 2 ORDER BY credits DESC;
