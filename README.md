# Datathlon · Group 8 data pipeline

Group project for **Data Engineering & Cloud Infrastructure** (Albert School, Laura Belmond).
We play the data engineering team of **Datathlon**, a fictional omnichannel sports retailer (an obvious Decathlon parody), and present its data pipeline to the CDO.

- **Team:** Khaled Elnagar, Robin Cacarié, Rudy
- **Upload deadline:** Wed 4 Nov 2026 (slides, architecture, Git link, ~30 s pipeline video)
- **Oral defense:** Fri 6 Nov 2026, 11:30, 15 min

## The pipeline in one line

5 sources (web orders, store tills, warehouse stock, weather, holidays) → Google Cloud Storage → **Snowflake** (bronze → silver → gold, bad rows to quarantine) with **dbt**, scheduled by **Snowflake Tasks** → **Streamlit** dashboard. Everything on **Google Cloud** (Frankfurt, `europe-west3`), built with **Terraform**.

Use cases: **UC1** daily omnichannel sales and revenue, **UC3** stock cover alert ([docs/USE_CASES.md](docs/USE_CASES.md)). Diagram: [architecture/](architecture/).

## Repository layout

| Folder | What goes in it | Build step |
| --- | --- | --- |
| [sources/](sources/) | The simulated company systems: Postgres web shop, till feed, stock export | 4, 6, 7 |
| [ingestion/](ingestion/) | Python jobs that move data into Snowflake: incremental orders, API pulls | 5, 7b |
| [snowflake/](snowflake/) | SQL run in Snowflake: account setup, stages, `COPY INTO`, Tasks | 0, 6, 7, 10 |
| [dbt/](dbt/) | The dbt project: seed, silver, quarantine, gold, tests, docs | 8, 9 |
| [terraform/](terraform/) | Infrastructure as code: Snowflake database, warehouses, roles; GCS buckets | 2, 3 |
| [gcp/](gcp/) | Google Cloud manual steps (team access, billing) | 0 |
| [dashboard/](dashboard/) | Streamlit app on the GOLD tables | 11 |
| [docs/](docs/) | Decisions, journal, use cases, build plan, requirements, TD inventory | all |
| [architecture/](architecture/) | Architecture diagram (Excalidraw + SVG) and the script that draws it | — |
| [brand/](brand/) | Logo, colors, fonts | — |

Each folder has its own README: what it does, where the code comes from (which TD), and how to run it.

## Getting started (each team member)

1. Accept the GitHub invitation, then clone: `git clone https://github.com/khaledngr/datathlon.git`
2. Copy the settings template and fill in **your own** values: `cp .env.example .env` (`.env` is never committed)
3. Snowflake: sign in at `https://app.snowflake.com/europe-west3.gcp/ge20484/` with your own user (`KHALED`, `RUDY`, `ROBINCCR`), set up MFA
4. Google Cloud: `gcloud auth login` with your `@albertschool.com` account, then `gcloud config set project datathlon-513514`

Details and the reasons behind each choice: [docs/SETUP.md](docs/SETUP.md).

## Secrets: the rules

- Passwords, private keys (`*.p8`), `.env` files, Terraform state and service-account keys **never** go in Git. `.gitignore` blocks them.
- Each person has their own logins; nobody shares a password (decision D-027).
- Scripts use **key pairs** (TD 2 `gen_key.py`), kept on your own laptop outside the repo; only the path goes in `.env`.

## Documentation

| File | What it holds |
| --- | --- |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Every decision: what we chose, why, what we rejected |
| [docs/JOURNAL.md](docs/JOURNAL.md) | Every action, in order, with the date |
| [docs/USE_CASES.md](docs/USE_CASES.md) | The use cases (decided first, tools follow) |
| [docs/BUILD_PLAN.md](docs/BUILD_PLAN.md) | The build, step by step, with owners and checks |
| [docs/SETUP.md](docs/SETUP.md) | Accounts, tools and settings each member needs |
| [docs/MANUAL_STEPS.md](docs/MANUAL_STEPS.md) | What is not in Terraform, and why |
| [docs/TD_INVENTORY.md](docs/TD_INVENTORY.md) | What each TD already built and how we reuse it |
| [docs/REQUIREMENTS.md](docs/REQUIREMENTS.md) | Project rules and the grading matrix |

## Working rules

1. **Use cases first, tools second.** The stack follows the use cases and will change as they do.
2. **TD stack first.** We reuse and adapt what we built in the TDs, because we understand it and can defend it. A new tool needs a reason in `DECISIONS.md`.
3. **Document as we go.** Every choice goes in `DECISIONS.md`, every action in `JOURNAL.md`, at the moment it happens.
4. **Step by step.** One build step at a time; the group reviews before the next one.
