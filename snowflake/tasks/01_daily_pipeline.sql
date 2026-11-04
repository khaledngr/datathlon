-- Datathlon · the daily pipeline inside Snowflake (step 10, D-043). Adapted from the resource pack
-- 06-orchestration-and-docker/snowflake-tasks/daily_pipeline_tasks.sql and TD 3.2 (dbt project started by a task).
--
--   05:30 Paris  Cloud Scheduler -> Cloud Run morning job: web orders -> BRONZE, till / stock / API files -> GCS
--   06:00 Paris  T_START ──┬─> T_LOAD_TILLS ──┐
--                          ├─> T_LOAD_STOCK ──┤ (stock reconciliation must pass, or the task FAILS)
--                          ├─> T_LOAD_API ────┼─> T_DBT_BUILD (EXECUTE DBT PROJECT: build = models + tests)
--                          └─> T_CHECK_WEB ───┘ (this morning's web load ran and reconciled, or FAILS)
--                T_FINALIZE (after every run, success or failure) -> OPS.PIPELINE_RUNS
--
-- Re-run safe: COPY INTO never loads a file twice, dbt rebuilds tables, so a retry never counts anything twice.
-- Owner: DATATHLON_ENGINEER (EXECUTE TASK granted by Terraform, terraform/roles.tf).
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/tasks/01_daily_pipeline.sql
-- Needs: dbt project deployed first (.venv/bin/python dbt/deploy_to_snowflake.py).

-- ---------- Run log ----------
CREATE TABLE IF NOT EXISTS DATATHLON.OPS.PIPELINE_RUNS (
    graph_run_group_id VARCHAR,
    finished_at        TIMESTAMP_TZ,
    tasks_succeeded    NUMBER,       -- final state of each task (after its retries)
    tasks_failed       NUMBER,
    retries            NUMBER,       -- extra attempts in this run (TASK_AUTO_RETRY_ATTEMPTS)
    failed_tasks       VARCHAR,
    first_error        VARCHAR,
    email_sent_to      NUMBER        -- how many people got the failure e-mail
) COMMENT = 'One row per run of the daily task graph, written by T_FINALIZE (step 10)';
ALTER TABLE DATATHLON.OPS.PIPELINE_RUNS ADD COLUMN IF NOT EXISTS email_error VARCHAR;  -- why the e-mail was not sent

-- Who gets the failure e-mail: verified e-mail addresses of users of this account. Filled in Snowflake, not in Git
-- (personal data): INSERT INTO DATATHLON.OPS.ALERT_RECIPIENTS SELECT email FROM SNOWFLAKE.ACCOUNT_USAGE.USERS WHERE ...
CREATE TABLE IF NOT EXISTS DATATHLON.OPS.ALERT_RECIPIENTS (email VARCHAR)
    COMMENT = 'Failure e-mail recipients (verified user e-mails), step 10';

-- ---------- The loads, as procedures (the COPY INTO of snowflake/stages/02-04, plus checks that FAIL) ----------
CREATE OR REPLACE PROCEDURE DATATHLON.OPS.LOAD_TILLS()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'COPY INTO till files (same as stages/02_tills.sql)'
EXECUTE AS OWNER
AS
$$
BEGIN
    COPY INTO DATATHLON.BRONZE.TILL_SALES_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
    FROM (
        SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
        FROM @DATATHLON.BRONZE.LANDING/tills/
    )
    FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
    PATTERN = '.*[.]json'
    ON_ERROR = 'CONTINUE';
    RETURN 'tills: ' || SQLROWCOUNT || ' rows loaded';
END;
$$;

CREATE OR REPLACE PROCEDURE DATATHLON.OPS.LOAD_STOCK()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'COPY INTO stock + control files, then the two-way reconciliation: a difference FAILS the task'
EXECUTE AS OWNER
AS
$$
DECLARE
    loaded INTEGER;
    bad_days INTEGER;
    stock_not_reconciled EXCEPTION (-20001, 'Stock NOT reconciled: a control file differs from its snapshot, or a snapshot has no control file (see stages/03_stock.sql)');
BEGIN
    COPY INTO DATATHLON.BRONZE.STOCK_SNAPSHOTS
    FROM (
        SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
        FROM @DATATHLON.BRONZE.LANDING/stock/
    )
    FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.CSV_HEADER')
    PATTERN = '.*stock_[0-9]{8}[.]csv'
    ON_ERROR = 'ABORT_STATEMENT';
    loaded := SQLROWCOUNT;

    COPY INTO DATATHLON.BRONZE.STOCK_CONTROL
    FROM (SELECT $1, $2, $3, $4, METADATA$FILENAME, CURRENT_TIMESTAMP() FROM @DATATHLON.BRONZE.LANDING/stock/)
    FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.CSV_HEADER')
    PATTERN = '.*control_[0-9]{8}[.]csv'
    ON_ERROR = 'ABORT_STATEMENT';

    SELECT COUNT(*) INTO :bad_days
    FROM DATATHLON.BRONZE.STOCK_CONTROL c
    FULL OUTER JOIN (SELECT snapshot_date, COUNT(*) AS n, SUM(on_hand) AS units
                     FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS GROUP BY 1) s
        ON s.snapshot_date = c.snapshot_date
    WHERE c.row_count IS DISTINCT FROM s.n OR c.on_hand_total IS DISTINCT FROM s.units;
    IF (bad_days > 0) THEN
        RAISE stock_not_reconciled;
    END IF;
    RETURN 'stock: ' || loaded || ' rows loaded, reconciled';
END;
$$;

CREATE OR REPLACE PROCEDURE DATATHLON.OPS.LOAD_API()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'COPY INTO weather and holiday API files (same as stages/04_api.sql)'
EXECUTE AS OWNER
AS
$$
DECLARE
    weather INTEGER;
BEGIN
    COPY INTO DATATHLON.BRONZE.WEATHER_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
    FROM (
        SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
        FROM @DATATHLON.BRONZE.LANDING/api/weather/
    )
    FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
    PATTERN = '.*[.]json'
    ON_ERROR = 'ABORT_STATEMENT';
    weather := SQLROWCOUNT;
    COPY INTO DATATHLON.BRONZE.HOLIDAYS_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
    FROM (
        SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
        FROM @DATATHLON.BRONZE.LANDING/api/holidays/
    )
    FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
    PATTERN = '.*[.]json'
    ON_ERROR = 'ABORT_STATEMENT';
    RETURN 'api: ' || weather || ' weather + ' || SQLROWCOUNT || ' holiday rows loaded';
END;
$$;

-- The web orders are loaded by the Docker morning job (Snowflake cannot reach the laptop's Postgres).
-- This check makes the graph FAIL if that job did not run today, did not reconcile, or did not reach yesterday.
CREATE OR REPLACE PROCEDURE DATATHLON.OPS.CHECK_WEB_LOAD()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'Fails unless today''s web load (Docker morning job) is reconciled and reaches yesterday'
EXECUTE AS OWNER
AS
$$
DECLARE
    runs_today INTEGER;
    last_day DATE;
    web_not_loaded EXCEPTION (-20002, 'Web orders NOT loaded this morning, or NOT reconciled: check the Docker morning job (logs/morning_job.log) and BRONZE.LOAD_RUNS');
    web_not_up_to_date EXCEPTION (-20003, 'Web orders in BRONZE do not reach yesterday: the morning job did not generate or load the last day');
BEGIN
    SELECT COUNT(*) INTO :runs_today
    FROM DATATHLON.BRONZE.LOAD_RUNS
    WHERE source = 'postgres.web_orders' AND reconciled
      AND CONVERT_TIMEZONE('Europe/Paris', finished_at)::DATE = CONVERT_TIMEZONE('Europe/Paris', CURRENT_TIMESTAMP())::DATE;
    IF (runs_today = 0) THEN
        RAISE web_not_loaded;
    END IF;
    SELECT MAX(order_ts)::DATE INTO :last_day FROM DATATHLON.BRONZE.WEB_ORDERS;
    IF (last_day < CURRENT_DATE() - 1) THEN
        RAISE web_not_up_to_date;
    END IF;
    RETURN 'web: loaded today, reconciled, orders up to ' || last_day;
END;
$$;

-- ---------- The task graph ----------
-- QUERY_TAG on every task: its credits go to the team that owns it in the showback (docs/GOVERNANCE.md).
-- Root: the schedule. CRON with a time zone handles summer / winter time.
-- SUSPEND_TASK_AFTER_NUM_FAILURES: a pipeline broken 3 days in a row stops instead of failing silently every day.
-- TASK_AUTO_RETRY_ATTEMPTS: a failed run is retried from the failed task; safe because every step is re-run safe.
CREATE OR REPLACE TASK DATATHLON.OPS.T_START
    WAREHOUSE = DATATHLON_WH
    QUERY_TAG = 'datathlon:transformation:t_start'
    SCHEDULE = 'USING CRON 0 6 * * * Europe/Paris'
    SUSPEND_TASK_AFTER_NUM_FAILURES = 3
    TASK_AUTO_RETRY_ATTEMPTS = 2
    USER_TASK_TIMEOUT_MS = 1800000
    COMMENT = 'Daily pipeline root, 06:00 Paris, after the 05:30 Docker morning job (D-043)'
AS
    SELECT 'daily pipeline started';

CREATE OR REPLACE TASK DATATHLON.OPS.T_LOAD_TILLS WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:ingestion:t_load_tills' AFTER DATATHLON.OPS.T_START
AS CALL DATATHLON.OPS.LOAD_TILLS();

CREATE OR REPLACE TASK DATATHLON.OPS.T_LOAD_STOCK WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:ingestion:t_load_stock' AFTER DATATHLON.OPS.T_START
AS CALL DATATHLON.OPS.LOAD_STOCK();

CREATE OR REPLACE TASK DATATHLON.OPS.T_LOAD_API WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:ingestion:t_load_api' AFTER DATATHLON.OPS.T_START
AS CALL DATATHLON.OPS.LOAD_API();

CREATE OR REPLACE TASK DATATHLON.OPS.T_CHECK_WEB WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:ingestion:t_check_web' AFTER DATATHLON.OPS.T_START
AS CALL DATATHLON.OPS.CHECK_WEB_LOAD();

-- dbt build = seeds + models + tests; a failed test (severity error) fails the task, so gold is never published
-- on top of bad data without the run showing red.
CREATE OR REPLACE TASK DATATHLON.OPS.T_DBT_BUILD WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:transformation:t_dbt_build'
    AFTER DATATHLON.OPS.T_LOAD_TILLS, DATATHLON.OPS.T_LOAD_STOCK, DATATHLON.OPS.T_LOAD_API, DATATHLON.OPS.T_CHECK_WEB
AS EXECUTE DBT PROJECT DATATHLON.OPS.DATATHLON_DBT ARGS = 'build --target prod';

-- Finalizer: runs at the end of every graph run, success OR failure: writes what happened, e-mails on failure.
CREATE OR REPLACE PROCEDURE DATATHLON.OPS.FINALIZE_RUN()
RETURNS VARCHAR LANGUAGE SQL
COMMENT = 'Called by T_FINALIZE: one row in OPS.PIPELINE_RUNS, and an e-mail if a task failed'
EXECUTE AS OWNER
AS
$$
DECLARE
    run_id VARCHAR;
    failed INTEGER;
    failed_names VARCHAR;
    error_text VARCHAR;
    recipients INTEGER;
    address VARCHAR;
    c_recipients CURSOR FOR SELECT DISTINCT email FROM DATATHLON.OPS.ALERT_RECIPIENTS WHERE email IS NOT NULL;
    sent INTEGER DEFAULT 0;
    email_error VARCHAR;
    attempt INTEGER;
BEGIN
    run_id := SYSTEM$TASK_RUNTIME_INFO('CURRENT_TASK_GRAPH_RUN_GROUP_ID');
    -- last attempt of each task of this run (a task that failed then succeeded on retry counts as succeeded)
    SELECT COUNT_IF(state = 'FAILED'), LISTAGG(IFF(state = 'FAILED', name, NULL), ', '),
           MIN(IFF(state = 'FAILED', error_message, NULL)), MAX(attempt_number)
      INTO :failed, :failed_names, :error_text, :attempt
    FROM (SELECT name, state, error_message, attempt_number
          FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TASK_HISTORY(
              SCHEDULED_TIME_RANGE_START => DATEADD('hour', -12, CURRENT_TIMESTAMP()), RESULT_LIMIT => 1000))
          WHERE graph_run_group_id = :run_id AND name <> 'T_FINALIZE'
          QUALIFY ROW_NUMBER() OVER (PARTITION BY name ORDER BY attempt_number DESC) = 1);

    -- the finalizer runs after every attempt: e-mail only once, when the automatic retries are used up
    -- (attempt 3 = 1 + TASK_AUTO_RETRY_ATTEMPTS of T_START; a manual RETRY LAST that fails again e-mails too)
    IF (failed > 0 AND attempt < 3) THEN
        email_error := 'attempt ' || attempt || ': waiting for the automatic retry before e-mailing';
    ELSEIF (failed > 0) THEN
        SELECT COUNT(DISTINCT email) INTO :recipients FROM DATATHLON.OPS.ALERT_RECIPIENTS;
        IF (recipients = 0) THEN
            email_error := 'no recipient in OPS.ALERT_RECIPIENTS';
        ELSE
            -- one e-mail per address: Snowflake refuses the whole send if one address is not verified, so one bad
            -- address must not silence the others. A broken e-mail never stops the run log below: errors are kept.
            FOR r IN c_recipients DO
                address := r.email;
                BEGIN
                    CALL SYSTEM$SEND_EMAIL('DATATHLON_ALERTS_EMAIL', :address,
                        'Datathlon daily pipeline FAILED: ' || :failed_names,
                        'Failed tasks: ' || :failed_names || '\nFirst error: ' || COALESCE(:error_text, '?') ||
                        '\nRun: ' || :run_id || '\nDetails: snowflake/tasks/02_task_history.sql or Snowsight > Monitoring > Task History');
                    sent := sent + 1;
                EXCEPTION
                    WHEN OTHER THEN
                        email_error := LEFT(COALESCE(email_error || '; ', '') || address || ': ' || SQLERRM, 500);
                END;
            END FOR;
        END IF;
    END IF;

    INSERT INTO DATATHLON.OPS.PIPELINE_RUNS
    SELECT :run_id, CURRENT_TIMESTAMP(),
           COUNT_IF(state = 'SUCCEEDED' AND is_last), COUNT_IF(state = 'FAILED' AND is_last), COUNT_IF(NOT is_last),
           :failed_names, :error_text, :sent, :email_error
    FROM (SELECT state, ROW_NUMBER() OVER (PARTITION BY name ORDER BY attempt_number DESC) = 1 AS is_last
          FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TASK_HISTORY(
              SCHEDULED_TIME_RANGE_START => DATEADD('hour', -12, CURRENT_TIMESTAMP()), RESULT_LIMIT => 1000))
          WHERE graph_run_group_id = :run_id AND name <> 'T_FINALIZE');
    RETURN IFF(failed > 0, 'run FAILED: ' || failed_names || ', e-mail to ' || sent, 'run OK');
END;
$$;

CREATE OR REPLACE TASK DATATHLON.OPS.T_FINALIZE WAREHOUSE = DATATHLON_WH QUERY_TAG = 'datathlon:transformation:t_finalize' FINALIZE = DATATHLON.OPS.T_START
AS CALL DATATHLON.OPS.FINALIZE_RUN();

-- Children first, root last: a task is created SUSPENDED, nothing runs before RESUME.
ALTER TASK DATATHLON.OPS.T_FINALIZE RESUME;
ALTER TASK DATATHLON.OPS.T_DBT_BUILD RESUME;
ALTER TASK DATATHLON.OPS.T_LOAD_TILLS RESUME;
ALTER TASK DATATHLON.OPS.T_LOAD_STOCK RESUME;
ALTER TASK DATATHLON.OPS.T_LOAD_API RESUME;
ALTER TASK DATATHLON.OPS.T_CHECK_WEB RESUME;
ALTER TASK DATATHLON.OPS.T_START RESUME;

SHOW TASKS IN SCHEMA DATATHLON.OPS;

-- Run now instead of waiting for 06:00:   EXECUTE TASK DATATHLON.OPS.T_START;
-- History (also Snowsight > Monitoring > Task History):  see snowflake/tasks/02_task_history.sql
-- Pause everything (no runs, no credits):  ALTER TASK DATATHLON.OPS.T_START SUSPEND;
