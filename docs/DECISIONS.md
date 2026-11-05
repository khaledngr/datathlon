# Decisions · why these tools, and what we did not choose

Every important choice, with the reason and the credible alternative we weighed. The numbers (D-0xx) are the ones quoted in the code comments. Who owns each part: [OWNERSHIP.md](OWNERSHIP.md).

## Platform

### D-026 · One cloud: Google Cloud, with Snowflake in the same region
- **Choice:** Google Cloud project `datathlon-513514` in **europe-west3 (Frankfurt)**, and the Snowflake account hosted on the same GCP region (`GCP_EUROPE_WEST3`).
- **Why:** one provider to learn, secure and pay; the team already worked on GCP and had school credits. Same region for storage (GCS) and compute (Snowflake): no transfer cost, lower latency, data stays in the EU (GDPR).
- **Alternatives:** AWS (S3 + Snowflake on AWS): equivalent technically, but a second account and a cloud the team knew less. BigQuery instead of Snowflake: fully serverless and native to GCP, but the course, the TDs and dbt Projects / Tasks / Streamlit inside the warehouse are Snowflake.

### D-031 · Infrastructure as code: Terraform for both clouds
- **Choice:** one `terraform/` folder creates the Snowflake side (database, 5 schemas, 2 warehouses, roles and grants, service user, storage integration, resource monitor) and the Google side (landing bucket, Cloud Run job, Cloud Scheduler, Cloud SQL, secrets, service accounts). Remote state in a private, versioned GCS bucket, with locking.
- **Why:** one `apply` links the two clouds (Snowflake's Google account gets read access on the bucket without copy-paste); any manual change shows up as drift in `terraform plan` (tested: a warehouse changed by hand was put back).
- **Alternatives:** clicking in the consoles (not reproducible, no review); SQL scripts for Snowflake only (would not cover Google Cloud). What Terraform cannot do is listed in [MANUAL_STEPS.md](MANUAL_STEPS.md).

### D-027 · Access: one login per person, least privilege
- **Choice:** each member has their own Snowflake user (password + MFA) and Google account; no shared login. Two project roles: `DATATHLON_ENGINEER` builds in the `DATATHLON` database, `DATATHLON_ANALYST` reads GOLD only. ACCOUNTADMIN only for what Snowflake allows nobody else to do (resource monitor, integrations).
- **Why:** graded access with an allowed / denied test ([snowflake/setup/02_access_test.sql](../snowflake/setup/02_access_test.sql), [dashboard/check_access.py](../dashboard/check_access.py)). Found while testing: Snowflake users have every role active at once by default (`DEFAULT_SECONDARY_ROLES = ALL`), so the tests switch secondary roles off; the service user has none.
- **Service user `DATATHLON_PIPELINE`:** `TYPE = SERVICE`, key pair only (a robot cannot answer an MFA prompt), only the engineer role. The pipeline does not depend on one person's account, and its queries are tagged so every action is traceable.

### D-029 · Cost guards on both clouds
- **Choice:** Snowflake resource monitor of 20 credits a month (notify at 50 / 80 %, suspend at 100 %, suspend immediately at 110 %) and a Google Cloud budget alert of €10 a month.
- **Why both:** each cloud bills separately; a guard on one does not see the other.
- **Alternatives:** a lower Snowflake cap (5 credits) could stop the pipeline during the live demo; automatic billing shutdown on GCP (Pub/Sub + function) is heavy for a trial. Measured costs and projection: [COSTS.md](COSTS.md).

## Use cases and sources

### D-013 · Two use cases: daily sales (UC1) and stock cover alert (UC2)
- **Choice:** UC1 tells category managers and the CFO which categories and channels to push; UC2 tells the supply chain what to restock before it runs out. Details: [USE_CASES.md](USE_CASES.md).
- **Why:** both answer a named pain point of the company (no single store + web view; stockouts ~4 % of sales lost), and UC2 reuses UC1's units sold, so one clean sales layer serves both.

### D-021 · Five sources, two of them real public APIs
- **Choice:** web shop orders (Postgres, OLTP), store tills (event files), store stock (daily CSV export), **weather** (Open-Meteo API, real) and **public and school holidays** (OpenHolidays API, real), plus the product and store catalogue as a dbt seed.
- **Why:** each source explains sales or stock (holidays and weather drive sports sales) and each brings a different ingestion method. The three internal systems are simulated because a fictional company has no real ones; we say so.
- **Alternatives:** data.gouv.fr for holidays (France only; OpenHolidays covers France, Belgium and Spain).
- **Weather in gold:** `gold_store_weather_daily` puts each store's weather next to its till sales and adds the 7-day forecast, so a manager can prepare the week. Our till generator does not use the weather, so we show it as context and claim no effect on sales.

### D-033 · The simulated data carries the patterns the dashboard must show
- **Choice:** the generators follow the real holiday calendar the pipeline loads: school holidays +60 %, back to school +30 %, weekends, category mix (hiking, cycling and swimming up in holidays). Deterministic (fixed seed per day).
- **Why:** a dashboard on random data shows nothing; with these rules, the effect is measurable in gold (hiking +62 % units per day in holidays) and checked by a test.

### D-014 · The live incident comes from the store tills
- **Choice:** the store channel of UC1 comes from a till feed that sends real-life defects (duplicates, missing IDs, unknown products, quantities like "two", prices in cents, dates in 2099, renamed fields).
- **Why:** it gives a live, visual incident in a source that matters (store revenue), a third ingestion method (micro-batch files), and dbt's quarantine catches it. **Alternative:** one bad row in the stock file: simpler but a single batch, less visual. The stock file is used for the second incident instead ([INCIDENTS.md](INCIDENTS.md)).

## Ingestion

### D-032 · Web shop: Postgres, now on Cloud SQL
- **Choice:** Postgres 16 with orders, order lines, products and stores; status paid / cancelled / refunded, test orders flagged. No personal data: customers are codes (GDPR by design).
- **Why:** the web shop is a transactional database (OLTP): rows are inserted and updated all day, which is what an incremental load has to handle.

### D-034 · Web orders: incremental load with a watermark and `MERGE`
- **Choice:** each morning, read only rows changed since the last load (`updated_at` watermark, 5-minute look-back), in one consistent snapshot, then `MERGE` into BRONZE (insert new, update changed). Reconciliation at the end of every run (Postgres counts = BRONZE counts), logged in `BRONZE.LOAD_RUNS`.
- **Why:** re-running never duplicates (tested: a second run merges 0 rows), refunds that change an old order are picked up.
- **Alternatives:** full reload every day (simple but grows with history); CDC with Debezium / Openflow (catches deletes, but the shop never deletes orders: it changes their status). Named as a limit.

### D-035 · Store tills: files → Cloud Storage → `COPY INTO`, raw kept as received
- **Choice:** the tills drop NDJSON files in the landing bucket; Snowflake loads them with `COPY INTO` into a `VARIANT` column with the file name and line number.
- **Why:** nothing is rejected or cleaned at load (the raw line is the evidence), and Snowflake's load history means a file is never loaded twice. Cleaning happens in dbt where it is tested.
- **Alternatives:** Snowpipe (continuous auto-ingest): right for real streaming, but our decisions are daily (D-022) and it needs bucket notifications; Kafka: far beyond the volume.

### D-036 · Weather and holidays: API pull → JSON files → `COPY INTO`
- **Choice:** a job calls the two APIs each morning, saves the raw JSON in the bucket, Snowflake loads it.
- **Why:** the raw answer is kept (can be replayed), and the load is the same pattern as the tills. A run that already has its files does not call the APIs again.

### D-037 · Store stock: daily CSV + control file, all or nothing
- **Choice:** one CSV per night count plus a control file (expected rows and units). `COPY INTO` with `ON_ERROR = ABORT_STATEMENT` and `NOT NULL` columns, then a two-way reconciliation (each control file = its snapshot, no snapshot without control).
- **Why:** half a stock count is wrong stock: better no new data (gold keeps yesterday's) than a false alert. Found by testing: a short line was loaded with NULLs until the columns became `NOT NULL`.

### D-049 · File formats: each source keeps its natural format; no Parquet, no Iceberg at this size
- **Choice:**

  | Data | Format in the bucket | Why this one | In Snowflake |
  | --- | --- | --- | --- |
  | Till sales | **NDJSON**, one JSON per line, a file every few seconds | A till appends one event at a time; each line stands alone, so a broken line never breaks the file; fields can be added or renamed (schema drift) without breaking the load | One `VARIANT` per line in BRONZE: nothing lost, parsed in dbt |
  | Weather, holidays | **JSON**, the API answer as returned | Replayable: we keep exactly what the API said | `VARIANT`, flattened in dbt |
  | Store stock | **CSV** with header + a control file | Fixed, flat columns from a legacy stock system; the format every store system can export; the control file proves the export is complete | Typed columns, `NOT NULL` |
  | Web orders | none: Postgres rows read with SQL | The source is a database; a file would add a step | Typed columns, `MERGE` |

  Inside Snowflake every table is stored the same way whatever the input: compressed, columnar micro-partitions, encrypted (AES-256).
- **Why not Parquet:** Parquet is columnar and compressed, the right choice for large analytical exports. Our files are small (a till file is about 2 KB, the whole bucket 12 MB) and written by operational systems that produce rows, not columns; converting them would add a step and hide the raw line we keep as evidence. Parquet becomes worth it when one export is hundreds of MB, for example the full 40,000-product stock count of 180 stores (7 M rows a night).
- **Why not Apache Iceberg (yet):** Iceberg is an open table format (Parquet files plus metadata: snapshots, schema evolution, time travel) that several engines (Spark, Trino, BigQuery, Snowflake) can read and write on the same files in our own bucket, without copying. It solves a multi-engine, vendor-independence problem we do not have: one engine (Snowflake) reads everything, and Snowflake's own tables already give time travel and schema changes. **When we would switch:** if a data science team wanted to read gold from Spark or BigQuery, gold would become Snowflake-managed Iceberg tables written to our GCS bucket (an external volume in Terraform, then one dbt setting: `table_format: iceberg`), the models themselves unchanged.
- **Alternatives:** Avro (row-based with a schema, the Kafka standard: right if the tills streamed through Kafka); CSV for the tills (a free-text field with a comma or a new line would break the file, no nesting).

## Transformation

### D-039 · dbt: bronze → silver + quarantine, with a seed
- **Choice:** dbt models clean each source into SILVER. Till lines that break a rule go to `QUARANTINE.QUARANTINE_TILL_SALES` with their reason; duplicates too. The catalogue is a dbt **seed** read from the same files the generators use.
- **Why:** every raw line ends up in exactly one place (silver or quarantine), and a test proves it on every build. Prices in cents are fixed against the catalogue, not with a "≥ 100" rule (Datathlon sells a €249 bike).
- **Alternatives:** cleaning in Python before loading (untested, raw lost); Snowflake stored procedures (no lineage, no tests, no docs).

### D-040 · dbt gold: one table per decision, a single source of truth
- **Choice:** `gold_sales_daily` (UC1), `gold_stock_cover_daily` (UC2), `gold_data_quality_daily`, `gold_holidays`, `gold_store_weather_daily` (weather per store and day, with the 7-day forecast). Rules: business day = UTC date; gold shows complete days only.
- **Why:** revenue is computed once, in gold, and tested against silver and against a day counted by hand; the dashboard only reads gold (pre-aggregated per day: cheap and fast).

## Orchestration and monitoring

### D-022 · Snowflake Tasks instead of Airflow
- **Choice:** a task graph inside Snowflake at 06:00: load tills, stock and API files and check the web load in parallel, then `dbt build` inside Snowflake, then a finalizer that logs the run and e-mails on failure. 2 automatic retries.
- **Why:** runs where the data is, nothing to host or keep running, fewer moving parts; dbt is skipped if a load fails, so gold is never built on bad data.
- **Alternatives:** Airflow in Docker (TDs): a server to keep alive and secure for one daily graph; Cloud Composer (managed Airflow on GCP): an always-on environment, several hundred dollars a month for one daily DAG.

### D-043 · Who starts what every morning
- **Choice:** what lives on the company side (reading the web shop, the till, stock and API exports) runs in one Docker image; what can run where the data is (loading, checks, dbt) runs in Snowflake.
- **Why:** Snowflake cannot reach the web shop database or run the source systems.

### D-044 · The morning job runs on Google Cloud: Cloud Run job + Cloud Scheduler
- **Choice:** Cloud Scheduler starts the Docker job on **Cloud Run** at 05:30 Paris; the web shop database is on **Cloud SQL**; secrets in Secret Manager; each machine has its own service account with only its rights.
- **Why:** a pipeline must not depend on a laptop being on (a real failure on 4 Nov proved it). Cloud Run jobs bill per second of run (~30 s a day).
- **Alternatives:** a VM with cron (a server to patch, paid all day); Neon free Postgres (outside Google Cloud, one more account); Postgres rebuilt inside the job (would make the incremental load meaningless).

## Visualisation and governance

### D-016 · Dashboard: Streamlit
- **Choice:** one Streamlit app reading GOLD only, three tabs titled with the use-case questions.
- **Why:** Python like the rest of the code, in the teacher's resource pack, runs inside Snowflake.
- **Alternatives:** Power BI (Windows only, paid sharing); Looker Studio (made for BigQuery); Metabase or Superset (one more server to run).

### D-045 · What the dashboard shows
- Freshness ("data up to"), source tables, queries cached 10 minutes, a read-only role on its own warehouse. Details in [dashboard/README.md](../dashboard/README.md).

### D-046 · The dashboard runs inside Snowflake
- **Choice:** Streamlit in Snowflake, owned by the read-only analyst role, on the BI warehouse, with a 5-minute sleep timer.
- **Why:** the data never leaves the governed platform and no key sits on a third-party host. **Alternative:** Streamlit Community Cloud: public by default, the Snowflake key stored in its secrets, data leaves Snowflake for every chart.

### D-047 · Incidents rehearsed on the real platform
- Two incidents (bad till data live, truncated stock file) run on the real pipeline, with their evidence: [INCIDENTS.md](INCIDENTS.md). They found a real time-zone bug, now fixed and tested.

### D-048 · Personal data masked by tag, costs shown per team
- **Choice:** a `PII` tag carries the masking policies: anyone but `DATATHLON_PII_READER` sees a SHA-256 of the customer code and loyalty card. Query tags give every credit to a team (`GOLD_COST_SHOWBACK_DAILY`), with a budget per warehouse. Details in [GOVERNANCE.md](GOVERNANCE.md).
- **Why:** a new personal column is masked by tagging it, with no new policy. Showback, not chargeback: there is no internal billing between three students, but the table is what a chargeback would bill.
- **Alternatives:** a masking policy per column (one more policy to forget for each new column); hashing in dbt only (bronze would still hold clear values); cost split by warehouse only (cannot separate ingestion from transformation, which share one).

### D-041 · The architecture diagram shows only what is built
- Every box on [architecture/](../architecture/) can be shown running; nothing decorative.
