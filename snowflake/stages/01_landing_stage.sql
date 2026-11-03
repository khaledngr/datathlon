-- Datathlon · the landing stage: ONE stage over the whole landing bucket, one folder per source (step 6, D-035)
--   tills/   store till files (step 6)      stock/   daily stock export (step 7)      api/   weather + holidays (7b)
-- The stage uses the storage integration created by Terraform (DATATHLON_GCS_INT): no key, no password.
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/stages/01_landing_stage.sql
CREATE STAGE IF NOT EXISTS DATATHLON.BRONZE.LANDING
    URL = 'gcs://datathlon-landing-513514/'
    STORAGE_INTEGRATION = DATATHLON_GCS_INT
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Landing bucket (GCS, Frankfurt): tills/, stock/, api/';

-- One JSON document per line (NDJSON), like the TD 3.3 kiosk feed
CREATE FILE FORMAT IF NOT EXISTS DATATHLON.BRONZE.NDJSON
    TYPE = JSON
    STRIP_OUTER_ARRAY = FALSE
    COMMENT = 'Newline-delimited JSON (till feed, API files)';

LIST @DATATHLON.BRONZE.LANDING/tills/2026/10/24/;
