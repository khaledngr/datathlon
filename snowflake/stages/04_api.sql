-- Datathlon · API files -> BRONZE: real weather (Open-Meteo) and real holidays (OpenHolidays) (step 7b)
-- Raw on purpose: one VARIANT per API call, as received. dbt (step 8) flattens the daily values and holiday periods.
-- Files come from ingestion/api_pull/pull_apis.py: gs://datathlon-landing-513514/api/{weather,holidays}/YYYY/MM/DD/
-- COPY INTO remembers the files it already loaded (64 days): re-running loads only NEW files, never twice.
-- Run: .venv/bin/python snowflake/run_sql.py snowflake/stages/04_api.sql
CREATE TABLE IF NOT EXISTS DATATHLON.BRONZE.WEATHER_RAW (
    raw            VARIANT,       -- envelope (source, url, run_date, fetched_at, store_id, city) + the API answer
    _file          VARCHAR,       -- METADATA$FILENAME: which file, so every row can be traced (lineage)
    _file_row      NUMBER,
    _file_modified TIMESTAMP_LTZ,
    _loaded_at     TIMESTAMP_TZ
) COMMENT = 'Open-Meteo daily weather per store, one row per API call, raw (step 7b)';

CREATE TABLE IF NOT EXISTS DATATHLON.BRONZE.HOLIDAYS_RAW (
    raw            VARIANT,       -- envelope (source, url, run_date, fetched_at, country, kind) + the API answer
    _file          VARCHAR,
    _file_row      NUMBER,
    _file_modified TIMESTAMP_LTZ,
    _loaded_at     TIMESTAMP_TZ
) COMMENT = 'OpenHolidays school and public holidays FR, BE, ES, one row per API call, raw (step 7b)';

COPY INTO DATATHLON.BRONZE.WEATHER_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
FROM (
    SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
    FROM @DATATHLON.BRONZE.LANDING/api/weather/
)
FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
PATTERN = '.*[.]json'
ON_ERROR = 'ABORT_STATEMENT';   -- an API file is all or nothing: a broken one stops the load and shows up

COPY INTO DATATHLON.BRONZE.HOLIDAYS_RAW (raw, _file, _file_row, _file_modified, _loaded_at)
FROM (
    SELECT $1, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, METADATA$FILE_LAST_MODIFIED, CURRENT_TIMESTAMP()
    FROM @DATATHLON.BRONZE.LANDING/api/holidays/
)
FILE_FORMAT = (FORMAT_NAME = 'DATATHLON.BRONZE.NDJSON')
PATTERN = '.*[.]json'
ON_ERROR = 'ABORT_STATEMENT';

SELECT 'WEATHER_RAW' AS table_name, COUNT(*) AS api_calls, COUNT(DISTINCT _file) AS files,
       COUNT(DISTINCT raw:store_id) AS stores_or_countries, MAX(raw:run_date::DATE) AS last_run
FROM DATATHLON.BRONZE.WEATHER_RAW
UNION ALL
SELECT 'HOLIDAYS_RAW', COUNT(*), COUNT(DISTINCT _file), COUNT(DISTINCT raw:country), MAX(raw:run_date::DATE)
FROM DATATHLON.BRONZE.HOLIDAYS_RAW;

-- What silver will do (step 8): one row per store and day, from the latest run
SELECT w.raw:store_id::STRING AS store_id, d.value::DATE AS day,
       w.raw:response:daily:temperature_2m_max[d.index]::FLOAT AS t_max,
       w.raw:response:daily:precipitation_sum[d.index]::FLOAT AS rain_mm
FROM DATATHLON.BRONZE.WEATHER_RAW w, LATERAL FLATTEN(w.raw:response:daily:time) d
WHERE w.raw:run_date::DATE = (SELECT MAX(raw:run_date::DATE) FROM DATATHLON.BRONZE.WEATHER_RAW)
  AND d.value::DATE = w.raw:run_date::DATE - 1
ORDER BY store_id;
