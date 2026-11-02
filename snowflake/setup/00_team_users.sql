-- =====================================================================================
-- Datathlon · step 0 · one Snowflake user per team member (decision D-027)
-- Account NVTLKDO-RP44213 (GCP europe-west3). Run once, by an ACCOUNTADMIN (today: ROBINCCR),
-- in a Snowsight SQL file: paste everything, then "Run all" (cmd+shift+Enter).
--
-- Why: nobody shares a login. Khaled is a second ACCOUNTADMIN so the team is not locked out
-- if Robin is unavailable. SYSADMIN is temporary: step 3 (Terraform) creates DATATHLON_ENGINEER
-- and DATATHLON_ANALYST, then we move everyone to DATATHLON_ENGINEER and revoke SYSADMIN.
-- =====================================================================================
USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS KHALED
    EMAIL = 'kelnagar@albertschool.com'
    DEFAULT_ROLE = SYSADMIN
    COMMENT = 'Datathlon Group 8 - Khaled - D-027';

CREATE USER IF NOT EXISTS RUDY
    EMAIL = 'rcausel@albertschool.com'
    DEFAULT_ROLE = SYSADMIN
    COMMENT = 'Datathlon Group 8 - Rudy - D-027';

GRANT ROLE ACCOUNTADMIN TO USER KHALED;
GRANT ROLE SYSADMIN     TO USER KHALED;
GRANT ROLE SYSADMIN     TO USER RUDY;

-- Passwords: the admin types a temporary one HERE, never in Git or chat.
-- Snowflake forces the person to choose a new one (and set up MFA) at first sign-in.
--   ALTER USER KHALED SET PASSWORD = '<temporary password>' MUST_CHANGE_PASSWORD = TRUE;
--   ALTER USER RUDY   SET PASSWORD = '<temporary password>' MUST_CHANGE_PASSWORD = TRUE;
-- Then send each person their temporary password privately (not in the group chat).

-- Check: 3 users, each with the right roles
SHOW USERS;
SHOW GRANTS TO USER KHALED;
SHOW GRANTS TO USER RUDY;
