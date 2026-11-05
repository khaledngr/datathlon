# Datathlon · data pipeline

Data platform for Datathlon, a fictional sports retailer with 8 stores and a web shop in France, Belgium and Spain. Project for *Data Engineering & Cloud Infrastructure*, Albert School.

![Architecture](architecture/datathlon-architecture.svg)

## What it does

| Use case | Question | Gold table |
| --- | --- | --- |
| **UC1 · Sales** | Which categories and channels should next week's promotions push? | `GOLD_SALES_DAILY` |
| **UC2 · Stock** | What should we restock, in which store, before it runs out? | `GOLD_STOCK_COVER_DAILY` |

Details and metrics: [docs/USE_CASES.md](docs/USE_CASES.md).

## How it works

| Step | Tool | Where |
| --- | --- | --- |
| Sources | Postgres (web shop), till and stock files, weather and holiday APIs | [sources/](sources/) |
| Landing | Google Cloud Storage, Frankfurt (`europe-west3`) | [ingestion/](ingestion/) |
| Load | `MERGE` for web orders, `COPY INTO` for files → **BRONZE** | [snowflake/stages/](snowflake/stages/) |
| Transform | dbt: **SILVER**, bad lines to **QUARANTINE**, **GOLD**; tests on every build | [dbt/](dbt/) |
| Schedule | 05:30 Cloud Run job, 06:00 Snowflake Tasks; a failed run e-mails the team | [orchestration/](orchestration/), [snowflake/tasks/](snowflake/tasks/) |
| Dashboard | Streamlit in Snowflake, read-only analyst role, GOLD only | [dashboard/](dashboard/) |
| Infrastructure | Terraform for Snowflake and Google Cloud | [terraform/](terraform/) |

## Run it

```bash
cp .env.example .env                                   # your own values
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
docker compose --env-file .env -f sources/postgres/docker-compose.yml up -d
```

First load, in this order:

```bash
.venv/bin/python sources/postgres/generate_orders.py --init       # web shop history
.venv/bin/python ingestion/incremental_orders/load_web_orders.py  # Postgres -> BRONZE
.venv/bin/python sources/tills/till_feed.py --history             # till files -> GCS
.venv/bin/python ingestion/api_pull/pull_apis.py                  # weather + holidays -> GCS
.venv/bin/python sources/stock/stock_export.py                    # stock files -> GCS
for f in snowflake/stages/0*.sql; do .venv/bin/python snowflake/run_sql.py "$f"; done  # GCS -> BRONZE
dbt/dbt.sh build                                                   # SILVER, QUARANTINE, GOLD + tests
```

After that it runs every morning: Cloud Run job at 05:30, Snowflake Tasks at 06:00.

## See the results

| What | How |
| --- | --- |
| Dashboard | Snowsight > Projects > Streamlit > *Datathlon · sales and stock*. Locally: `.venv/bin/streamlit run dashboard/streamlit_app.py` |
| Last night's run | [snowflake/tasks/02_task_history.sql](snowflake/tasks/02_task_history.sql) (`OPS.PIPELINE_RUNS`) |
| Quality | 77 dbt tests; rejected lines in `QUARANTINE.QUARANTINE_TILL_SALES` with their reason |
| Data documentation | `dbt/dbt.sh docs generate && dbt/dbt.sh docs serve` (lineage, every gold column) |

## Docs

- [SETUP.md](docs/SETUP.md): accounts, keys, sign-ins
- [INCIDENTS.md](docs/INCIDENTS.md): two incidents, rehearsed
- [DECISIONS.md](docs/DECISIONS.md): why each tool, and the alternatives
- [OWNERSHIP.md](docs/OWNERSHIP.md): who owns which part
- [COSTS.md](docs/COSTS.md): what it costs, measured and projected
- [GOVERNANCE.md](docs/GOVERNANCE.md): tags, masking of personal data, showback, budgets
- [MANUAL_STEPS.md](docs/MANUAL_STEPS.md): what Terraform cannot do
- [CLEANUP.md](docs/CLEANUP.md): switching everything off

## Rules

- **Secrets never go in Git** (`.env`, `*.p8`, Terraform state): `.gitignore` blocks them.
- **One login per person**; scripts use key pairs.
- **Changes go through a pull request** on `main`.
