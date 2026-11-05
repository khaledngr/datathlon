-- =====================================================================================================================
-- Datathlon · native data quality monitoring on BRONZE (docs/GOVERNANCE.md). Re-run safe.
--   .venv/bin/python snowflake/run_sql.py snowflake/setup/06_data_quality_monitoring.sql
-- Needs the grants of terraform/governance.tf (EXECUTE DATA METRIC FUNCTION, DATA_METRIC_USER, the results viewer).
--
-- dbt tests check what dbt builds, when dbt runs. Data metric functions (DMFs) are Snowflake's own monitors: they
-- measure the raw tables every morning at 06:20, after the 06:00 run, on serverless compute, and keep every value in
-- SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS. An alert at 06:30 compares the latest values with the limits in
-- OPS.DATA_QUALITY_RULES and e-mails the team if one is broken: a source that stopped sending, an order loaded twice,
-- a till sending too many lines without a sale ID. Only BRONZE: dbt re-creates silver and gold on every build, which
-- would drop their monitors.
-- =====================================================================================================================
USE ROLE DATATHLON_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DATATHLON_WH;

-- ---------- 1. Two metrics Snowflake does not have ----------
-- Share of the till lines of the last day of loads that have no sale ID (the live feed sends ~4 %, the history ~1 %).
-- "Last day" = the 24 h before the newest load: a metric must give the same value on the same data (no CURRENT_TIMESTAMP)
CREATE OR REPLACE DATA METRIC FUNCTION DATATHLON.OPS.PCT_TILL_LINES_WITHOUT_SALE_ID_24H(
    t TABLE (raw VARIANT, loaded_at TIMESTAMP_TZ))
RETURNS NUMBER
COMMENT = 'Percent of the till lines loaded in the 24 h before the newest load with no sale ID'
AS
$$
    SELECT COALESCE(ROUND(100 * COUNT_IF(raw:sale_id IS NULL OR IS_NULL_VALUE(raw:sale_id) OR raw:sale_id::STRING = '')
                          / NULLIF(COUNT(*), 0), 2), 0)
    FROM t
    WHERE loaded_at > (SELECT DATEADD('hour', -24, MAX(loaded_at)) FROM t)
$$;

-- Night counts present twice for the same store, product and day (a stock file loaded twice)
CREATE OR REPLACE DATA METRIC FUNCTION DATATHLON.OPS.DUPLICATE_STOCK_COUNTS(
    t TABLE (store_id VARCHAR, sku VARCHAR, snapshot_date DATE))
RETURNS NUMBER
COMMENT = 'Store x product x day keys present more than once in the stock counts'
AS
$$
    SELECT COUNT(*) FROM (SELECT store_id, sku, snapshot_date FROM t GROUP BY ALL HAVING COUNT(*) > 1)
$$;

-- ---------- 2. When to measure: every morning after the 06:00 run ----------
ALTER TABLE DATATHLON.BRONZE.WEB_ORDERS      SET DATA_METRIC_SCHEDULE = 'USING CRON 20 6 * * * Europe/Paris';
ALTER TABLE DATATHLON.BRONZE.TILL_SALES_RAW  SET DATA_METRIC_SCHEDULE = 'USING CRON 20 6 * * * Europe/Paris';
ALTER TABLE DATATHLON.BRONZE.STOCK_SNAPSHOTS SET DATA_METRIC_SCHEDULE = 'USING CRON 20 6 * * * Europe/Paris';
ALTER TABLE DATATHLON.BRONZE.WEATHER_RAW     SET DATA_METRIC_SCHEDULE = 'USING CRON 20 6 * * * Europe/Paris';

-- ---------- 3. What to measure (a metric already attached is kept: re-run safe) ----------
EXECUTE IMMEDIATE $$
DECLARE
    metrics ARRAY DEFAULT ARRAY_CONSTRUCT(
        'ALTER TABLE DATATHLON.BRONZE.WEB_ORDERS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()',
        'ALTER TABLE DATATHLON.BRONZE.WEB_ORDERS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (_loaded_at)',
        'ALTER TABLE DATATHLON.BRONZE.WEB_ORDERS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (order_id)',
        'ALTER TABLE DATATHLON.BRONZE.WEB_ORDERS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (order_ts)',
        'ALTER TABLE DATATHLON.BRONZE.TILL_SALES_RAW ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()',
        'ALTER TABLE DATATHLON.BRONZE.TILL_SALES_RAW ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (_loaded_at)',
        'ALTER TABLE DATATHLON.BRONZE.TILL_SALES_RAW ADD DATA METRIC FUNCTION DATATHLON.OPS.PCT_TILL_LINES_WITHOUT_SALE_ID_24H ON (raw, _loaded_at)',
        'ALTER TABLE DATATHLON.BRONZE.STOCK_SNAPSHOTS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()',
        'ALTER TABLE DATATHLON.BRONZE.STOCK_SNAPSHOTS ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (_loaded_at)',
        'ALTER TABLE DATATHLON.BRONZE.STOCK_SNAPSHOTS ADD DATA METRIC FUNCTION DATATHLON.OPS.DUPLICATE_STOCK_COUNTS ON (store_id, sku, snapshot_date)',
        'ALTER TABLE DATATHLON.BRONZE.WEATHER_RAW ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (_loaded_at)');
    statement VARCHAR;
    added INTEGER DEFAULT 0;
    kept VARCHAR DEFAULT '';
BEGIN
    FOR i IN 0 TO ARRAY_SIZE(metrics) - 1 DO
        statement := metrics[i]::VARCHAR;
        BEGIN
            EXECUTE IMMEDIATE :statement;
            added := added + 1;
        EXCEPTION
            WHEN OTHER THEN kept := kept || ' | ' || SQLERRM;
        END;
    END FOR;
    RETURN added || ' metrics attached (one already attached is kept as is)' || IFF(kept = '', '', ', errors:' || kept);
END;
$$;

-- ---------- 4. The limits: one row per table and metric ----------
CREATE OR REPLACE TABLE DATATHLON.OPS.DATA_QUALITY_RULES (
    table_name  VARCHAR COMMENT 'BRONZE table',
    metric_name VARCHAR COMMENT 'Data metric function name',
    max_value   NUMBER  COMMENT 'Broken above this value',
    why         VARCHAR COMMENT 'What a breach means'
) COMMENT = 'Limits for the data metric functions on BRONZE, read by the alert OPS.A_DATA_QUALITY'
AS SELECT * FROM VALUES
    ('WEB_ORDERS',      'FRESHNESS',       93600, 'No web order loaded for 26 h: the morning job did not run'),
    ('WEB_ORDERS',      'DUPLICATE_COUNT', 0,     'An order ID twice in BRONZE: the MERGE was bypassed'),
    ('WEB_ORDERS',      'NULL_COUNT',      0,     'An order without a date: the web shop sent a broken row'),
    ('TILL_SALES_RAW',  'FRESHNESS',       93600, 'No till file loaded for 26 h: the tills or the load stopped'),
    ('TILL_SALES_RAW',  'PCT_TILL_LINES_WITHOUT_SALE_ID_24H', 5, 'Over 5 % of yesterday''s till lines have no sale ID: a till is failing'),
    ('STOCK_SNAPSHOTS', 'FRESHNESS',       93600, 'No stock count loaded for 26 h: the stock export did not arrive'),
    ('STOCK_SNAPSHOTS', 'DUPLICATE_STOCK_COUNTS', 0, 'A stock count present twice: a file was loaded twice'),
    ('WEATHER_RAW',     'FRESHNESS',       93600, 'No weather loaded for 26 h: the API pull did not run');

-- ---------- 5. Latest value of every metric, against its limit ----------
CREATE OR REPLACE VIEW DATATHLON.OPS.DATA_QUALITY_STATUS
COMMENT = 'Latest data metric value per BRONZE table and metric, with its limit and status (alert OPS.A_DATA_QUALITY)'
AS
WITH latest AS (
    SELECT table_name, metric_name, value, measurement_time
    FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
    WHERE table_database = 'DATATHLON' AND table_schema = 'BRONZE'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY table_name, metric_name ORDER BY measurement_time DESC) = 1
)
SELECT l.table_name, l.metric_name, l.value, r.max_value,
       IFF(l.value > r.max_value, 'BROKEN', IFF(r.max_value IS NULL, 'measured', 'ok')) AS status,
       r.why, CONVERT_TIMEZONE('Europe/Paris', l.measurement_time)::TIMESTAMP_NTZ AS measured_paris
FROM latest l
LEFT JOIN DATATHLON.OPS.DATA_QUALITY_RULES r USING (table_name, metric_name);

-- ---------- 6. The alert: 06:30, e-mails each verified team address if a limit is broken ----------
CREATE OR REPLACE PROCEDURE DATATHLON.OPS.NOTIFY_DATA_QUALITY()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'Called by the alert A_DATA_QUALITY: one e-mail per address listing the broken data quality limits'
EXECUTE AS OWNER
AS
$$
DECLARE
    body VARCHAR;
    address VARCHAR;
    sent INTEGER DEFAULT 0;
    c_recipients CURSOR FOR SELECT DISTINCT email FROM DATATHLON.OPS.ALERT_RECIPIENTS WHERE email IS NOT NULL;
BEGIN
    SELECT LISTAGG(table_name || ' ' || metric_name || ' = ' || value || ' (limit ' || max_value || '): ' || why, '\n')
      INTO :body
    FROM DATATHLON.OPS.DATA_QUALITY_STATUS WHERE status = 'BROKEN';
    FOR r IN c_recipients DO
        address := r.email;
        BEGIN
            CALL SYSTEM$SEND_EMAIL('DATATHLON_ALERTS_EMAIL', :address,
                                   'Datathlon: data quality limit broken in BRONZE', :body);
            sent := sent + 1;
        EXCEPTION
            WHEN OTHER THEN NULL;   -- an unverified address must not stop the others (same rule as FINALIZE_RUN)
        END;
    END FOR;
    RETURN sent || ' e-mail(s) sent';
END;
$$;

CREATE OR REPLACE ALERT DATATHLON.OPS.A_DATA_QUALITY
    WAREHOUSE = DATATHLON_WH
    SCHEDULE = 'USING CRON 30 6 * * * Europe/Paris'
    COMMENT = 'Data quality limits on BRONZE (OPS.DATA_QUALITY_STATUS), checked after the 06:20 measurements'
    IF (EXISTS (SELECT 1 FROM DATATHLON.OPS.DATA_QUALITY_STATUS WHERE status = 'BROKEN'))
    THEN CALL DATATHLON.OPS.NOTIFY_DATA_QUALITY();
ALTER ALERT DATATHLON.OPS.A_DATA_QUALITY RESUME;

-- ---------- 7. Check ----------
SELECT * FROM TABLE(INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
    REF_ENTITY_NAME => 'DATATHLON.BRONZE.TILL_SALES_RAW', REF_ENTITY_DOMAIN => 'table'));
-- Measure now instead of waiting for 06:20 (same functions, run on demand):
SELECT SNOWFLAKE.CORE.FRESHNESS(SELECT _loaded_at FROM DATATHLON.BRONZE.TILL_SALES_RAW) AS till_seconds_since_last_load,
       SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT order_id FROM DATATHLON.BRONZE.WEB_ORDERS) AS duplicate_order_ids,
       DATATHLON.OPS.PCT_TILL_LINES_WITHOUT_SALE_ID_24H(SELECT raw, _loaded_at FROM DATATHLON.BRONZE.TILL_SALES_RAW) AS pct_no_sale_id_24h,
       DATATHLON.OPS.DUPLICATE_STOCK_COUNTS(SELECT store_id, sku, snapshot_date FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS) AS duplicate_stock_counts;
SHOW ALERTS IN SCHEMA DATATHLON.OPS;
