# What the TDs already give us

Inventory made on 2 Nov 2026 from the local folders `td2/`, `td3/`, `td4/` and `redgrave-platform/` (Khaled's TD work, AFC Redgrave example).
When we reuse a file, we copy it into `datathlon/`, rename Redgrave → Datathlon, and write in `JOURNAL.md` which TD file it came from.

| TD | What we built | Files to adapt | Covers (grading) |
| --- | --- | --- | --- |
| **TD 1.1** · Architecture | Excalidraw architecture with OLTP / OLAP labels on every source | (diagram) | Slides, C8 |
| **TD 2** · Ingestion | Local **Postgres** (merch database) → **Snowflake** bronze, twice: **batch** (export CSV → stage → `COPY INTO`) and **incremental** (watermark on `updated_at` + `MERGE`, re-runs never duplicate). Key-pair login, read-only grader role | `td2/onprem-to-snowflake/01…06_*.sql`, `incremental_orders.py`, `gen_key.py` | C3 ingestion, C6 replay, C7 access |
| **TD 3.1 / 3.2** · dbt | dbt Core medallion: bronze sources → 3 silver views → 3 gold tables (daily sales, revenue by channel, top products), tests, a reconciliation test (gold = silver), run logging macro | `redgrave-platform/redgrave_dbt/` | C3 transformations, C6 checks |
| **TD 3.3** · Data quality | Python **feed simulator** sending sales every 5 s with real defects (duplicates, prices in pence or "£4.50", future dates, renamed column, unknown products). dbt: staging → silver → **quarantine**, **seed** product catalogue, tests "every row accounted for" and "prices match catalogue", a data-quality gold table | `td3/data-quality-lab/kiosk_sales_generator.py`, `redgrave-platform/redgrave_kiosk_dbt/` | Incident demo, seed, C6 |
| **TD 4.1** · Docker | Images vs containers, Docker Compose stacks, Portainer | `td4/docker-compose.yml`, `td4/dbt_image/Dockerfile` | C3 containerised job |
| **TD 4.2** · Airflow + Terraform | Airflow 3 in Docker; daily DAG `ingest → dbt build → publish` with `DockerOperator`, 2 retries, failure alert, publishes D-1 with `MERGE` (idempotent, backfills work). Terraform: Snowflake database, schema, 2 warehouses via a module, analyst role + grants, drift detection. GitHub Actions runs `terraform plan` on every pull request | `redgrave-platform/airflow/`, `redgrave-platform/terraform/`, `.github/workflows/terraform-plan.yml` | C3 launch, C5 IaC, C6 scheduling, C7 roles |

## The teacher's oral defense resource pack

Drive `Oral defense/Oral-defense-resource-pack.zip`, found on 2 Nov 2026. Ready-made examples for the project, several directly useful to us:

| Folder | What is in it | Useful for |
| --- | --- | --- |
| `02-messy-data-generator/` | Script that generates dirty data | Ideas for more bad rows in the till feed |
| `03-cleaning-examples/dbt/` | dbt project with silver, **quarantine** and a test "quarantine below 15 %" | Our quarantine models and tests |
| `04-source-databases/` | Docker Compose for source databases + Postgres loader | Our local Postgres |
| `05-ingestion-methods/` | COPY, Snowpipe, write_pandas, incremental watermark, API, Kafka | Our three ingestion methods |
| `06-orchestration-and-docker/` | Airflow DAGs (incl. `redgrave_daily.py`), dbt-runner and ingest-job Dockerfiles, Snowflake tasks | Airflow + Docker |
| `07-data-quality-and-alerting/` | Airflow Slack alert callback, webhook, Snowflake quality alerts | Failure alerts (C6) |
| `08-visualisation/` | Dashboard tool comparison + **Streamlit app** | Our dashboard (D-016) |
| `09-iac/gcp/`, `09-iac/snowflake/` | Terraform for a GCS landing bucket (also BigQuery, which we do not use), and for Snowflake | Our Terraform (C5), D-026 |

## What the TDs do not cover yet

| Gap | Needed for | Options to decide later |
| --- | --- | --- |
| A dashboard | Demo step 3 "visualize" | Streamlit, proposed in D-016 (from the resource pack) |
| A third logical source beyond orders and the live feed | "At least 3 sources" | Inventory CSV / MySQL, an external API (weather), a seed |
| GCP resources | D-026 (GCP) | GCS bucket for files and Terraform state, read access for Snowflake's service account (pack `09-iac/gcp`) |
| Budget alert and cleanup procedure | C7 | Snowflake resource monitor (alert 80 %, suspend 100 %), GCP budget alert |
| Remote Terraform state | C5 "protected state" | `backend.tf.example` already exists; point it to a GCS bucket (`backend "gcs"`, locking built in) |

## Open check

- Done 2 Nov: the TD Snowflake account (`RXTWCXB-MJ49606`) is on `AWS_EU_WEST_3` (AWS Paris), so it stays for TD work only. The project uses the new account `NVTLKDO-RP44213` on `GCP_EUROPE_WEST3` (D-026).
