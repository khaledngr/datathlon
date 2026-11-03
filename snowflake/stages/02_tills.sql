-- Datathlon · till feed: files -> BRONZE, adapted from TD 3.3 02_load_files_option_b.sql (step 6, D-035)
-- Raw on purpose: one VARIANT per line, nothing cleaned here. dbt (step 8) cleans it and sends bad rows to quarantine.
-- COPY INTO remembers the files it already loaded (64 days): re-running loads only NEW files, never twice.
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/stages/02_tills.sql
CREATE TABLE IF NOT EXISTS DATATHLON.BRONZE.TILL_SALES_RAW (
    raw            VARIANT,       -- the till line exactly as sent
    _file          VARCHAR,       -- METADATA$FILENAME: which file, so every row can be traced (lineage)
    _file_row      NUMBER,        -- line number in that file
    _file_modified TIMESTAMP_LTZ, -- when the file landed in the bucket
    _loaded_at     TIMESTAMP_TZ
) COMMENT = 'Store till lines, raw (micro-batch files from GCS, step 6)';

COPY INTO DATATHLON.BRONZE.TILL_SALES_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
FROM (
    SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
    FROM @DATATHLON.BRONZE.LANDING/tills/
)
FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
PATTERN = '.*[.]json'
ON_ERROR = 'CONTINUE';   -- a broken line is skipped and reported, it does not block the other files

SELECT COUNT(*) AS rows_in_bronze, COUNT(DISTINCT _file) AS files, MIN(_loaded_at) AS first_load, MAX(_loaded_at) AS last_load
FROM DATATHLON.BRONZE.TILL_SALES_RAW;
