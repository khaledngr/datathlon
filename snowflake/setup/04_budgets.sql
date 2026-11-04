-- =====================================================================================================================
-- Datathlon · budgets (docs/GOVERNANCE.md). Run once in Snowsight as ACCOUNTADMIN, after `terraform apply` (it needs
-- the schema GOVERNANCE). Re-run safe. Terraform cannot declare Snowflake budgets yet, so they live here.
--
-- Resource monitors (Terraform) STOP the warehouses at the cap. Budgets do not stop anything: they watch the spend of
-- the objects they hold, forecast the end of the month and e-mail the team when the forecast goes over the limit.
-- One budget per team that pays:
--   account     20 credits   everything (= the account resource monitor)
--   pipeline    12 credits   DATATHLON_WH: ingestion (Khaled) + transformation (Robin), split in gold_cost_showback_daily
--   dashboard    5 credits   DATATHLON_BI_WH: BI (Rudy) (= the BI resource monitor)
-- =====================================================================================================================
USE ROLE ACCOUNTADMIN;

-- Budgets e-mail through our notification integration; Snowflake's budget service must be allowed to use it
GRANT USAGE ON INTEGRATION DATATHLON_ALERTS_EMAIL TO APPLICATION SNOWFLAKE;

-- 1. Account budget: the built-in root budget, switched on
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!ACTIVATE();
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_SPENDING_LIMIT(20);

-- 2. Team budgets, in the GOVERNANCE schema
CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS DATATHLON.GOVERNANCE.BUDGET_PIPELINE()
    COMMENT = 'Pipeline warehouse: ingestion (Khaled) + transformation (Robin), 12 credits a month';
CALL DATATHLON.GOVERNANCE.BUDGET_PIPELINE!SET_SPENDING_LIMIT(12);
CALL DATATHLON.GOVERNANCE.BUDGET_PIPELINE!ADD_RESOURCE(
    SYSTEM$REFERENCE('WAREHOUSE', 'DATATHLON_WH', 'SESSION', 'applybudget'));

CREATE SNOWFLAKE.CORE.BUDGET IF NOT EXISTS DATATHLON.GOVERNANCE.BUDGET_DASHBOARD()
    COMMENT = 'Dashboard warehouse: BI (Rudy), 5 credits a month';
CALL DATATHLON.GOVERNANCE.BUDGET_DASHBOARD!SET_SPENDING_LIMIT(5);
CALL DATATHLON.GOVERNANCE.BUDGET_DASHBOARD!ADD_RESOURCE(
    SYSTEM$REFERENCE('WAREHOUSE', 'DATATHLON_BI_WH', 'SESSION', 'applybudget'));

-- 3. Who is told: the pipeline alert recipients (OPS.ALERT_RECIPIENTS, not in Git), verified addresses only
EXECUTE IMMEDIATE $$
DECLARE
    recipients VARCHAR;
BEGIN
    SELECT LISTAGG(DISTINCT email, ',') INTO :recipients FROM DATATHLON.OPS.ALERT_RECIPIENTS WHERE email IS NOT NULL;
    CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!SET_EMAIL_NOTIFICATIONS('DATATHLON_ALERTS_EMAIL', :recipients);
    CALL DATATHLON.GOVERNANCE.BUDGET_PIPELINE!SET_EMAIL_NOTIFICATIONS('DATATHLON_ALERTS_EMAIL', :recipients);
    CALL DATATHLON.GOVERNANCE.BUDGET_DASHBOARD!SET_EMAIL_NOTIFICATIONS('DATATHLON_ALERTS_EMAIL', :recipients);
    RETURN 'budget e-mails to ' || :recipients;
END;
$$;

-- 4. Check: the limits and what each budget has spent this month (also in Snowsight > Admin > Cost management > Budgets)
CALL SNOWFLAKE.LOCAL.ACCOUNT_ROOT_BUDGET!GET_SPENDING_LIMIT();
CALL DATATHLON.GOVERNANCE.BUDGET_PIPELINE!GET_LINKED_RESOURCES();
CALL DATATHLON.GOVERNANCE.BUDGET_DASHBOARD!GET_LINKED_RESOURCES();
SHOW SNOWFLAKE.CORE.BUDGET IN ACCOUNT;
