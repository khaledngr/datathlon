-- =====================================================================================
-- Datathlon · step 3b · proof that the roles work (C7: "allowed / denied verification")
-- Roles are created by Terraform (terraform/roles.tf). Run in Snowsight, one block at a time.
--
-- IMPORTANT: Snowflake turns on ALL of a user's roles by default (DEFAULT_SECONDARY_ROLES = ALL),
-- so a member who is also ACCOUNTADMIN can do everything whatever role is selected.
-- USE SECONDARY ROLES NONE keeps only the chosen role: without it this test proves nothing.
-- =====================================================================================

-- 1. As engineer: create one test table in GOLD and one in BRONZE (allowed)
USE ROLE DATATHLON_ENGINEER;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DATATHLON_WH;
CREATE OR REPLACE TABLE DATATHLON.GOLD.ACCESS_TEST AS SELECT 1 AS ok;
CREATE OR REPLACE TABLE DATATHLON.BRONZE.ACCESS_TEST AS SELECT 1 AS ok;

-- 2. As analyst
USE ROLE DATATHLON_ANALYST;
USE SECONDARY ROLES NONE;
USE WAREHOUSE DATATHLON_BI_WH;
SELECT * FROM DATATHLON.GOLD.ACCESS_TEST;            -- allowed: returns 1
SELECT * FROM DATATHLON.BRONZE.ACCESS_TEST;          -- denied: schema does not exist or not authorized
INSERT INTO DATATHLON.GOLD.ACCESS_TEST VALUES (2);   -- denied: no INSERT
USE WAREHOUSE DATATHLON_WH;                          -- denied: pipeline warehouse not granted

-- 3. Clean up
USE ROLE DATATHLON_ENGINEER;
DROP TABLE IF EXISTS DATATHLON.GOLD.ACCESS_TEST;
DROP TABLE IF EXISTS DATATHLON.BRONZE.ACCESS_TEST;
