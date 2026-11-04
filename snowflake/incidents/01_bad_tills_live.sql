-- Datathlon · incident 1 evidence: bad till data sent live (step 12). Run before and after the live feed:
--   .venv/bin/python snowflake/run_sql.py snowflake/incidents/01_bad_tills_live.sql

-- 1. Every raw till line is in silver OR quarantine, exactly once (= dbt test assert_till_rows_accounted_for)
SELECT (SELECT COUNT(*) FROM DATATHLON.BRONZE.TILL_SALES_RAW)        AS raw_rows,
       (SELECT COUNT(*) FROM DATATHLON.SILVER.SILVER_TILL_SALES)     AS silver_rows,
       (SELECT COUNT(*) FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES) AS quarantine_rows,
       raw_rows - silver_rows - quarantine_rows                       AS unaccounted;

-- 2. The live files (named live_*): lines kept, lines quarantined, % quarantined
SELECT COUNT(DISTINCT r._file) AS live_files, COUNT(*) AS raw_lines, COUNT(q._file) AS quarantined,
       ROUND(100 * COUNT(q._file) / NULLIF(COUNT(*), 0), 1) AS pct_quarantined
FROM DATATHLON.BRONZE.TILL_SALES_RAW r
LEFT JOIN DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES q USING (_file, _file_row)
WHERE CONTAINS(r._file, '/live_');

-- 3. Why the live lines were quarantined
SELECT reject_reason, COUNT(*) AS lines
FROM DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES
WHERE CONTAINS(_file, '/live_')
GROUP BY reject_reason ORDER BY lines DESC;

-- 4. The same rate on the history files, for comparison (a quarter of the live rate, D-014)
SELECT IFF(CONTAINS(r._file, '/live_'), 'live', 'history') AS feed, COUNT(*) AS raw_lines,
       COUNT(q._file) AS quarantined, ROUND(100 * COUNT(q._file) / COUNT(*), 1) AS pct_quarantined
FROM DATATHLON.BRONZE.TILL_SALES_RAW r
LEFT JOIN DATATHLON.QUARANTINE.QUARANTINE_TILL_SALES q USING (_file, _file_row)
GROUP BY feed;

-- 5. The live files in Snowflake's load history (COPY_HISTORY): each loaded once, none refused
SELECT COUNT(*) AS live_files_loaded, COUNT(DISTINCT file_name) AS distinct_files, SUM(row_count) AS row_total,
       COUNT_IF(status <> 'Loaded') AS not_loaded
FROM TABLE(DATATHLON.INFORMATION_SCHEMA.COPY_HISTORY(
    TABLE_NAME => 'DATATHLON.BRONZE.TILL_SALES_RAW', START_TIME => DATEADD('day', -3, CURRENT_TIMESTAMP())))
WHERE file_name IN (SELECT _file FROM DATATHLON.BRONZE.TILL_SALES_RAW WHERE CONTAINS(_file, '/live_'));
