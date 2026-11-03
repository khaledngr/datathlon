-- Datathlon · what did the daily pipeline do? (step 10 evidence, C5 / C6; same as Snowsight > Monitoring > Task History)
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/tasks/02_task_history.sql

-- 1. One row per graph run, written by the finalizer
SELECT finished_at, tasks_succeeded, tasks_failed, retries, failed_tasks, LEFT(first_error, 120) AS first_error,
       email_sent_to, LEFT(email_error, 80) AS email_error
FROM DATATHLON.OPS.PIPELINE_RUNS
ORDER BY finished_at DESC
LIMIT 10;

-- 2. Every task of the last 2 days: state, attempt (retries), duration, what it returned or why it failed
SELECT name, state, attempt_number, scheduled_time, completed_time,
       DATEDIFF('second', query_start_time, completed_time) AS seconds,
       LEFT(COALESCE(error_message, return_value), 120) AS result
FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -2, CURRENT_TIMESTAMP()), RESULT_LIMIT => 200))
WHERE database_name = 'DATATHLON'
ORDER BY scheduled_time DESC, query_start_time DESC;

-- 3. dbt runs inside Snowflake: one row per model / test, from the run log macro
SELECT MIN(run_at) AS run_at, ANY_VALUE(command) AS command, ANY_VALUE(target_user) AS run_by, COUNT(*) AS nodes,
       COUNT_IF(status IN ('error', 'fail')) AS failed
FROM DATATHLON.GOLD.DBT_RUN_RESULTS
GROUP BY invocation_id
ORDER BY run_at DESC
LIMIT 5;

-- 4. Next scheduled run and state of the graph
SHOW TASKS IN SCHEMA DATATHLON.OPS;
