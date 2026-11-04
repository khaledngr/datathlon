# Build plan

**Status: Proposed (D-020), waiting for the group.** We build one step at a time. After each step: Claude reports what was done and how it was checked, the group reviews, and we only move on once the group says so.

Each step says where its code comes from (TD or the teacher's resource pack, see [TD_INVENTORY.md](TD_INVENTORY.md)), who should own it (D-017), and how we check it is done.

| # | Step | Reuses | Owner (D-017) | Done when |
| --- | --- | --- | --- | --- |
| 0 ✅ | **Accounts and checks** (done 2 Nov for Khaled and Robin; Rudy's password and GitHub invite, Robin's billing activation and Khaled's MFA carry over): Snowflake account `NVTLKDO-RP44213` on GCP Frankfurt (done: region checked); GCP project `datathlon-513514` (Robin's); Google Cloud CLI on the laptop; GitHub repo; own access for each member | — | all | `gcloud config list` shows the project; each member signs in to Snowflake with their own user; everyone can push to the repo |
| 1 ✅ | **Repo skeleton** (done 2 Nov, waiting for the group's review): folders, README, `.gitignore`, `.env.example`, where secrets live (never in Git) | TD 4.2 repo layout | all | Repo pushed; `git status` shows no secret files |
| 2 ✅ | **Cost guard first** (done 2 Nov, D-029): Snowflake resource monitor `DATATHLON_ACCOUNT_MONITOR` (20 credits/month: email 50 % and 80 %, stop 100 %, hard stop 110 %) and GCP budget `datathlon-cost-guard` (€10/month, before credits, emails 50/90/100 % + forecast 100 %) | pack `09-iac/`, TD 4.2 | UC3 owner | Alert visible in Snowflake and GCP consoles |
| 3 ✅ | **Terraform base** (done 3 Nov: 3a keys + state bucket, 3b Snowflake base, 3c bucket + storage integration, 3d drift demo + [manual steps](MANUAL_STEPS.md)): Snowflake database, schemas (BRONZE, SILVER, GOLD, QUARANTINE), warehouses, roles; GCS bucket in `europe-west3` + Snowflake storage integration (Snowflake's service account gets read access to the bucket); Terraform state in GCS | TD 4.2 `terraform/`, pack `09-iac/gcp` (bucket part only) + `09-iac/snowflake` | UC3 owner | `terraform plan` shows no changes after `apply` |
| 4 ✅ | **Source 1, web orders** (done 3 Nov, D-032): local Postgres in Docker with Datathlon orders, order lines, products | TD 2, pack `04-source-databases` | UC1 owner | Row counts in Postgres match the generator |
| 5 ✅ | **Ingestion 1, incremental** (done 3 Nov, D-034): Postgres → BRONZE with watermark + `MERGE` | TD 2 `incremental_orders.py` | UC1 owner | Second run loads 0 rows (no duplicates) |
| 6 ✅ | **Source 2 + ingestion 2, till feed** (done 3 Nov, D-035): generator → JSON files → GCS → `COPY INTO` BRONZE | TD 3.3 `kiosk_sales_generator.py` | data-quality owner | Files in GCS; `METADATA$FILENAME` filled in BRONZE |
| 7 ✅ | **Source 3 + ingestion 3, stock** (done 3 Nov, D-037): daily CSV → GCS → `COPY INTO` BRONZE | TD 2 Part A | UC3 owner | Snapshot total in BRONZE = CSV total |
| 7b ✅ | **Sources 4 and 5 + ingestion 4, APIs** (done 3 Nov, D-036): Open-Meteo weather and OpenHolidays holidays → JSON → GCS → `COPY INTO` BRONZE | pack `05-ingestion-methods/snowflake/05_api_to_snowflake.py` | UC3 owner | Re-run the same day adds no duplicates; a timeout fails loudly |
| 8 ✅ | **dbt silver + quarantine + seed** (done 3 Nov, D-039): product catalogue seed, cleaning, bad rows to QUARANTINE, tests | TD 3.1–3.3, pack `03-cleaning-examples/dbt` | data-quality owner | `dbt build` green; every raw row in silver or quarantine |
| 9 ✅ | **dbt gold** (done 3 Nov, D-040): UC1 sales by day × channel × category; UC3 days of cover; data quality table; reconciliation test | TD 3.2 gold models | UC1 / UC3 owners | Gold = silver test passes; numbers match a hand-checked day |
| 10 ✅ | **Docker + Snowflake Tasks** (done 3 Nov, D-041; moved to Cloud Run + Cloud Scheduler + Cloud SQL on 4 Nov, D-042): Python ingestion job in Docker; task graph 06:00 → COPY INTO → MERGE → dbt build → gold, with retries, finalizer and email alert | TD 4.1, pack `06-orchestration-and-docker/snowflake-tasks`, `07-` | UC1 owner | Task history green; a forced failure retries without double counting |
| 11 ✅ | **Streamlit dashboard** on GOLD (done 4 Nov, D-043) | pack `08-visualisation` | data-quality owner | Opens on the laptop; numbers match gold |
| 12 | **Rehearse the 2 incidents, collect evidence, finish README and dbt docs** | — | all | Both incidents run live; run IDs and screenshots saved |

Steps 4 to 7 can run in parallel once step 3 is done.
