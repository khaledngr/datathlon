-- Datathlon · daily stock snapshot: CSV -> BRONZE, adapted from TD 2 Part A 04_copy_into.sql (step 7, D-037)
-- Files from sources/stock/stock_export.py: gs://datathlon-landing-513514/stock/YYYY/MM/DD/
--   stock_YYYYMMDD.csv    one row per store x product, counted at night
--   control_YYYYMMDD.csv  what the stock system says it sent: row count and units on hand (batch control file)
-- Typed columns (the export is a clean system file, unlike the tills). ON_ERROR = ABORT_STATEMENT: a half-loaded
-- snapshot would give wrong stock for a whole store, so a broken file stops the load and shows up.
-- NOT NULL on purpose: with a SELECT ($1..$7) in COPY, a line with missing columns is NOT rejected, the missing
-- columns just become NULL (found in testing, D-037). NOT NULL makes Snowflake reject that line.
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/stages/03_stock.sql
CREATE FILE FORMAT IF NOT EXISTS DATATHLON.BRONZE.CSV_HEADER
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'CSV with one header line (stock export)';

CREATE TABLE IF NOT EXISTS DATATHLON.BRONZE.STOCK_SNAPSHOTS (
    snapshot_date DATE NOT NULL,
    store_id      VARCHAR NOT NULL,
    sku           VARCHAR NOT NULL,
    on_hand       NUMBER NOT NULL,
    received      NUMBER NOT NULL,          -- delivered by the warehouse that day (Monday, Thursday)
    emergency     NUMBER NOT NULL,          -- emergency transfer from another store that day
    counted_at    TIMESTAMP_TZ NOT NULL,
    _file         VARCHAR,         -- METADATA$FILENAME (lineage)
    _file_row     NUMBER,
    _loaded_at    TIMESTAMP_TZ
) COMMENT = 'Night stock count per store x product, one CSV per day (step 7, UC2)';

CREATE TABLE IF NOT EXISTS DATATHLON.BRONZE.STOCK_CONTROL (
    snapshot_date DATE,
    file_name     VARCHAR,
    row_count     NUMBER,
    on_hand_total NUMBER,
    _file         VARCHAR,
    _loaded_at    TIMESTAMP_TZ
) COMMENT = 'Control file sent with each stock CSV: expected rows and units (step 7)';

COPY INTO DATATHLON.BRONZE.STOCK_SNAPSHOTS
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @DATATHLON.BRONZE.LANDING/stock/
)
FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.CSV_HEADER')
PATTERN = '.*stock_[0-9]{8}[.]csv'
ON_ERROR = 'ABORT_STATEMENT';

COPY INTO DATATHLON.BRONZE.STOCK_CONTROL
FROM (SELECT $1, $2, $3, $4, METADATA$FILENAME, CURRENT_TIMESTAMP() FROM @DATATHLON.BRONZE.LANDING/stock/)
FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.CSV_HEADER')
PATTERN = '.*control_[0-9]{8}[.]csv'
ON_ERROR = 'ABORT_STATEMENT';

-- Reconciliation (C6), both ways: every control file matches its snapshot, and no snapshot day comes without a
-- control file. Expected: 0 rows.
WITH s AS (SELECT snapshot_date, COUNT(*) AS rows_in_bronze, SUM(on_hand) AS units_in_bronze
           FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS GROUP BY 1)
SELECT COALESCE(c.snapshot_date, s.snapshot_date) AS snapshot_date, c.row_count, s.rows_in_bronze,
       c.on_hand_total, s.units_in_bronze
FROM DATATHLON.BRONZE.STOCK_CONTROL c
FULL OUTER JOIN s ON s.snapshot_date = c.snapshot_date
WHERE c.row_count IS DISTINCT FROM s.rows_in_bronze OR c.on_hand_total IS DISTINCT FROM s.units_in_bronze;

SELECT COUNT(DISTINCT snapshot_date) AS days, COUNT(*) AS rows_in_bronze, SUM(on_hand) AS units_on_hand_all_days,
       MAX(snapshot_date) AS last_snapshot
FROM DATATHLON.BRONZE.STOCK_SNAPSHOTS;
