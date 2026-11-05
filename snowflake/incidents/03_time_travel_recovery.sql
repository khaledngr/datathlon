-- =====================================================================================================================
-- Datathlon · incident 3: data deleted or dropped by mistake, recovered with Time Travel (docs/INCIDENTS.md).
-- Run in Snowsight one block at a time, or in one go:  .venv/bin/python snowflake/run_sql.py snowflake/incidents/03_time_travel_recovery.sql
-- Everything ends exactly as it started (checked by the last query). Rehearsed 5 Nov on zero-copy clones of the two
-- tables (1,500 stock rows deleted and put back, identical; the dropped table back with its 16 rows).
-- Snowflake keeps every change for 1 day (DATA_RETENTION_TIME_IN_DAYS = 1). BRONZE tables are permanent: after that day,
-- 7 more days of Fail-safe (Snowflake support only). dbt's tables (SILVER, GOLD) are transient, dbt's default: Time
-- Travel but no Fail-safe, so no Fail-safe storage to pay for data that one dbt build re-creates from BRONZE.
-- =====================================================================================================================
USE ROLE DATATHLON_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DATATHLON_WH;

-- ---------- A. A DELETE without its WHERE clause on raw data ----------
-- BRONZE is the layer that cannot be rebuilt: the stock files leave the bucket after 90 days.
SET before = CURRENT_TIMESTAMP();
SELECT COUNT(*) AS rows_before, SUM(on_hand) AS units_before FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS;

-- The mistake: the last week of night counts is gone
DELETE FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS WHERE snapshot_date >= DATEADD('day', -7, CURRENT_DATE());
SELECT COUNT(*) AS rows_now, SUM(on_hand) AS units_now FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS;

-- Time Travel: the table as it was before the mistake is still readable
SELECT COUNT(*) AS rows_then, SUM(on_hand) AS units_then
FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS AT (TIMESTAMP => $before);

-- Recovery: put back exactly the deleted rows, read from the past. INSERT into the same table rather than a clone
-- swapped in: a clone has no load history, so the next COPY INTO would load every stock file a second time.
INSERT INTO DATATHLON.BRONZE.STOCK_SNAPSHOTS
SELECT * FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS AT (TIMESTAMP => $before)
WHERE snapshot_date >= DATEADD('day', -7, CURRENT_DATE());

SELECT COUNT(*) AS rows_after, SUM(on_hand) AS units_after FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS;

-- ---------- B. A table dropped by mistake ----------
-- The dashboard reads GOLD_HOLIDAYS for its holiday shading: dropped, the dashboard breaks.
DROP TABLE DATATHLON.GOLD.GOLD_HOLIDAYS;
SHOW TABLES LIKE 'GOLD_HOLIDAYS' IN SCHEMA DATATHLON.GOLD;     -- nothing
SHOW TABLES HISTORY LIKE 'GOLD_HOLIDAYS' IN SCHEMA DATATHLON.GOLD;  -- still there, with a dropped_on date

UNDROP TABLE DATATHLON.GOLD.GOLD_HOLIDAYS;                       -- back with its rows, grants and tags

-- The analyst can read it again, with the same grant as before
USE ROLE DATATHLON_ANALYST;
USE WAREHOUSE DATATHLON_BI_WH;
SELECT COUNT(*) AS holidays_readable_by_analyst FROM DATATHLON.GOLD.GOLD_HOLIDAYS;

-- ---------- Check: everything is exactly as before ----------
USE ROLE DATATHLON_ENGINEER;
USE WAREHOUSE DATATHLON_WH;
SELECT n.rows_now = b.rows_before AND n.units_now = b.units_before AS stock_identical_to_before,
       n.rows_now, b.rows_before
FROM (SELECT COUNT(*) AS rows_now, SUM(on_hand) AS units_now FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS) n,
     (SELECT COUNT(*) AS rows_before, SUM(on_hand) AS units_before
      FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS AT (TIMESTAMP => $before)) b;
