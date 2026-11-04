-- =====================================================================================================================
-- Datathlon · what the platform has cost so far, from Snowflake's own metering (docs/COSTS.md)
-- Run in Snowsight as ACCOUNTADMIN (ACCOUNT_USAGE and ORGANIZATION_USAGE are only readable there). Read-only.
-- ACCOUNT_USAGE lags by up to 3 hours: the last hours of today are not in it yet.
-- =====================================================================================================================

-- 1. The cap: credits used this month against the 20-credit resource monitor (step 2)
SHOW RESOURCE MONITORS LIKE 'DATATHLON_ACCOUNT_MONITOR';

-- 2. What was billed, in dollars, per day and type (the price per credit of our account is in it)
SELECT usage_date, usage_type, ROUND(usage, 3) AS credits, ROUND(usage_in_currency, 2) AS usd
FROM SNOWFLAKE.ORGANIZATION_USAGE.USAGE_IN_CURRENCY_DAILY
ORDER BY usage_date, usd DESC;

-- 3. Credits per warehouse: pipeline (DATATHLON_WH) vs dashboard (DATATHLON_BI_WH)
SELECT warehouse_name, ROUND(SUM(credits_used), 3) AS credits, ROUND(SUM(credits_used_cloud_services), 3) AS cloud_services
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
GROUP BY 1 ORDER BY 2 DESC;

-- 4. Credits per job: every script and dbt run sets a query tag datathlon:* (sf_connect.py), the dashboard has its own
SELECT COALESCE(NULLIF(query_tag, ''), '(no tag: tasks, Snowsight)') AS job, COUNT(*) AS queries,
       ROUND(SUM(credits_attributed_compute), 4) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_ATTRIBUTION_HISTORY
GROUP BY 1 ORDER BY 3 DESC LIMIT 15;

-- 5. One scheduled run: how long the task graph kept the warehouse busy (billed time = this + 60 s auto-suspend)
SELECT graph_run_group_id,
       MIN(CONVERT_TIMEZONE('Europe/Paris', query_start_time))::TIMESTAMP_NTZ AS started_paris,
       DATEDIFF(second, MIN(query_start_time), MAX(completed_time)) AS seconds,
       LISTAGG(DISTINCT state, ', ') AS states
FROM SNOWFLAKE.ACCOUNT_USAGE.TASK_HISTORY
WHERE database_name = 'DATATHLON'
GROUP BY 1 ORDER BY 2 DESC LIMIT 5;

-- 6. Storage (bytes stored by the database, incl. Time Travel; Fail-safe on top)
SELECT usage_date, ROUND(average_database_bytes / 1e9, 3) AS gb, ROUND(average_failsafe_bytes / 1e9, 3) AS failsafe_gb
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE database_name = 'DATATHLON' ORDER BY usage_date DESC LIMIT 3;
