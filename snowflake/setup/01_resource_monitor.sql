-- =====================================================================================
-- Datathlon · step 2 · cost guard on Snowflake (decision D-029)
-- Account NVTLKDO-RP44213. Run once by an ACCOUNTADMIN.
--
-- The trial has $400 of credits (about 100 credits). We cap the project at 20 credits a month:
-- an XSMALL warehouse uses 1 credit per hour, so 20 credits = 20 hours of compute, far more than
-- the daily pipeline needs (a few minutes a day), and it leaves most of the trial untouched.
--   50 % -> email   80 % -> email   100 % -> suspend warehouses (running queries finish)
--   110 % -> suspend immediately (running queries are cancelled)
-- Covers every warehouse of the account. It does NOT cover serverless features (serverless tasks,
-- Snowpipe): our Tasks therefore run on a warehouse (WAREHOUSE = ...), so they stay under the cap.
-- Terraform will take this monitor over in step 3 (import), so it is declared as code too.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS DATATHLON_ACCOUNT_MONITOR
    WITH CREDIT_QUOTA = 20
         FREQUENCY = MONTHLY
         START_TIMESTAMP = IMMEDIATELY
         -- Only users with a VERIFIED email can be listed (Snowsight → Settings → My profile).
         -- First run had ROBINCCR only; KHALED added after he verified his email (2 Nov):
         -- ALTER RESOURCE MONITOR DATATHLON_ACCOUNT_MONITOR SET NOTIFY_USERS = (ROBINCCR, KHALED);
         NOTIFY_USERS = (ROBINCCR, KHALED)
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = DATATHLON_ACCOUNT_MONITOR;

-- Check: quota, used credits, level = ACCOUNT
SHOW RESOURCE MONITORS;
