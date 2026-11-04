-- =====================================================================================================================
-- Datathlon · governance, shown live (docs/GOVERNANCE.md). Run in Snowsight, one block at a time. Read-only.
-- Run `USE SECONDARY ROLES NONE` first: otherwise every role you have is active at once and hides what one role sees.
-- =====================================================================================================================
USE SECONDARY ROLES NONE;
USE WAREHOUSE DATATHLON_WH;

-- 1. Dynamic masking. As an engineer, the personal identifiers come out as SHA-256 pseudonyms
USE ROLE DATATHLON_ENGINEER;
SELECT order_id, customer_ref FROM DATATHLON.BRONZE.WEB_ORDERS ORDER BY order_id LIMIT 5;
SELECT raw:sale_id::STRING AS sale_id, raw:loyalty_id::STRING AS loyalty_id
FROM DATATHLON.BRONZE.TILL_SALES_RAW WHERE raw:loyalty_id IS NOT NULL LIMIT 5;

-- ... and in clear for the role allowed to see them (admins only, as their primary role)
USE ROLE DATATHLON_PII_READER;
SELECT order_id, customer_ref FROM DATATHLON.BRONZE.WEB_ORDERS ORDER BY order_id LIMIT 5;
SELECT raw:sale_id::STRING AS sale_id, raw:loyalty_id::STRING AS loyalty_id
FROM DATATHLON.BRONZE.TILL_SALES_RAW WHERE raw:loyalty_id IS NOT NULL LIMIT 5;

-- The analyst cannot even reach BRONZE (refused): masking is a second wall, not the only one
USE ROLE DATATHLON_ANALYST;
USE WAREHOUSE DATATHLON_BI_WH;
SELECT customer_ref FROM DATATHLON.BRONZE.WEB_ORDERS LIMIT 1;   -- expected error: does not exist or not authorized

-- 2. Tags: every tag on our objects, with the ones a table inherits from its schema
USE ROLE DATATHLON_ENGINEER;
USE WAREHOUSE DATATHLON_WH;
SELECT tag_name, tag_value, level, object_name, column_name, apply_method
FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('DATATHLON.BRONZE.WEB_ORDERS', 'table'));
SELECT tag_name, tag_value, level, apply_method
FROM TABLE(DATATHLON.INFORMATION_SCHEMA.TAG_REFERENCES('DATATHLON.GOLD.GOLD_SALES_DAILY', 'table'));

-- Account-wide view (Snowflake's own, up to 2 h late): which objects carry which tag
SELECT tag_name, tag_value, domain, object_name, column_name
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE tag_database = 'DATATHLON' AND object_deleted IS NULL
ORDER BY tag_name, tag_value, domain, object_name;

-- 3. Showback / chargeback: who spent what, this month
SELECT cost_center, owner, ROUND(SUM(total_credits), 3) AS credits, ROUND(SUM(total_usd), 2) AS usd
FROM DATATHLON.GOLD.GOLD_COST_SHOWBACK_DAILY
WHERE usage_date >= DATE_TRUNC('month', CURRENT_DATE())
GROUP BY 1, 2 ORDER BY credits DESC;

-- 4. Budgets (snowflake/setup/04_budgets.sql): limits and spend
SHOW SNOWFLAKE.CORE.BUDGET IN ACCOUNT;
