# Datathlon · data pipeline

Project for *Data Engineering & Cloud Infrastructure*, Albert School. Datathlon is a fictional omnichannel sports retailer; this is its data platform.

**Sources** (web shop, store tills, stock, weather, holidays) → **Google Cloud Storage** → **Snowflake** (bronze → silver → gold, with **dbt**) → **Streamlit** dashboard. Infrastructure in **Terraform**, everything in Frankfurt (`europe-west3`).

![Architecture](architecture/datathlon-architecture.svg)

**Use cases:** daily omnichannel sales (UC1) and stock cover alert (UC2), see [docs/USE_CASES.md](docs/USE_CASES.md).

## Quick start

```bash
cp .env.example .env                                   # fill in your own values
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
docker compose --env-file .env -f sources/postgres/docker-compose.yml up -d
```

Load the data, in this order (the stock follows the web and till sales):

```bash
.venv/bin/python sources/postgres/generate_orders.py --init       # web shop history
.venv/bin/python ingestion/incremental_orders/load_web_orders.py  # Postgres -> BRONZE
.venv/bin/python sources/tills/till_feed.py --history             # till files -> GCS
.venv/bin/python ingestion/api_pull/pull_apis.py                  # weather + holidays -> GCS
.venv/bin/python sources/stock/stock_export.py                    # stock files -> GCS
for f in snowflake/stages/0*.sql; do .venv/bin/python snowflake/run_sql.py "$f"; done  # GCS -> BRONZE
dbt/dbt.sh build                                                   # BRONZE -> SILVER / QUARANTINE -> GOLD, tests
```

Every day after that, nothing to type (step 10, D-043): at **05:30** Cloud Scheduler starts the morning job on Cloud Run (web orders from Postgres on Cloud SQL, till, API and stock files, see [orchestration/](orchestration/), D-044), at **06:00** Snowflake Tasks load the files, check them and run dbt inside Snowflake ([snowflake/tasks/](snowflake/tasks/)).

## See the results

- **Dashboard:** Snowsight > Projects > Streamlit > *Datathlon · sales and stock* (`DATATHLON.APPS.DATATHLON_DASHBOARD`, read-only analyst role, GOLD only, D-046). On the laptop: `.venv/bin/streamlit run dashboard/streamlit_app.py`. See [dashboard/](dashboard/).
- **Data documentation:** `dbt/dbt.sh docs generate && dbt/dbt.sh docs serve` (lineage graph, every gold column described). The same descriptions are table and column comments in Snowflake.
- **Did last night's run work?** [snowflake/tasks/02_task_history.sql](snowflake/tasks/02_task_history.sql): one row per run in `OPS.PIPELINE_RUNS`, every task and retry, every dbt run in `GOLD.DBT_RUN_RESULTS`. A failed run e-mails the team.
- **Quality:** 71 dbt tests on every build (keys, accepted values, relationships, every raw till line in silver or quarantine exactly once, stock reconciled against its control file). Rejected till lines stay in `QUARANTINE.QUARANTINE_TILL_SALES` with their reason.

Accounts, keys and sign-ins: [docs/SETUP.md](docs/SETUP.md). Switching everything off: [docs/CLEANUP.md](docs/CLEANUP.md). What happens when data goes wrong (2 incidents, rehearsed): [docs/INCIDENTS.md](docs/INCIDENTS.md). What it costs, measured and projected: [docs/COSTS.md](docs/COSTS.md). Why each tool, and the alternatives: [docs/DECISIONS.md](docs/DECISIONS.md). Who owns which part: [docs/OWNERSHIP.md](docs/OWNERSHIP.md). Tags, masking of personal data, showback and budgets: [docs/GOVERNANCE.md](docs/GOVERNANCE.md).

## Repository

| Folder | Contents |
| --- | --- |
| [sources/](sources/) | Simulated company systems and the shared catalogue |
| [ingestion/](ingestion/) | Python jobs that load data into Snowflake |
| [orchestration/](orchestration/) | Morning job: Docker image on Cloud Run + Cloud Scheduler (outside Snowflake) |
| [snowflake/](snowflake/) | SQL run in Snowflake (setup, stages, Tasks, incident scripts) |
| [dbt/](dbt/) | Transformations and tests |
| [terraform/](terraform/) | Infrastructure as code (Snowflake + Google Cloud) |
| [dashboard/](dashboard/) | Streamlit app |
| [docs/](docs/) | Use cases, setup, incidents, costs, switching off; slide visuals in [docs/slides/](docs/slides/) |

## Rules

- **Secrets never go in Git** (`.env`, `*.p8`, Terraform state): `.gitignore` blocks them.
- **One login per person**; scripts use key pairs.
- **Changes go through a pull request** on `main`.
