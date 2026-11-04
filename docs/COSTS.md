# Costs · what the prototype cost, and what Datathlon would pay

Measured on 4 Nov 2026 from Snowflake's own metering ([snowflake/setup/03_cost_report.sql](../snowflake/setup/03_cost_report.sql), run as ACCOUNTADMIN) and from the Google Cloud resources themselves. Everything ran on free trial credits: **€0 out of pocket**.

## 1. The prototype (2 → 4 Nov)

| | Measured | Dollars |
| --- | --- | --- |
| Snowflake compute | **4.9 credits** of the 20-credit monthly cap (resource monitor) | **$17.07** billed up to 4 Nov, i.e. **$3.90 per credit** (our account's rate, GCP Frankfurt) |
| Snowflake storage | 0.09 GB (all layers, 71k bronze rows) | under $0.01 a month |
| Cloud SQL (web shop database, `db-f1-micro`, 10 GB HDD) | running since 3 Nov | about €0.40 a day (list price): the only GCP item that costs per hour |
| Cloud Run job, Cloud Scheduler, Artifact Registry (80 MB), bucket (12 MB), Secret Manager | 30 s per morning run, 1 scheduler job | within the free tiers |

Exact GCP figure: Billing > Reports on Robin's billing account (budget `datathlon-cost-guard`, €10 a month).

**Where the Snowflake credits went** (query 3 and 4 of the report):

| | Credits | Share |
| --- | --- | --- |
| Pipeline warehouse `DATATHLON_WH`: building, testing, dbt runs, incidents, the scheduled runs | 2.5 | 50 % |
| Dashboard warehouse `DATATHLON_BI_WH` (of which 1.9 is the Streamlit app inside Snowflake) | 2.4 | 49 % |
| Other (first trial warehouse, cloud services) | 0.1 | 1 % |

**One scheduled run** (query 5): the 06:00 task graph with dbt inside Snowflake keeps the XSMALL warehouse busy **40 s** (4 Nov, 10:00 run, all green), then it suspends after 60 s. Billed: about **0.03 credit, $0.11 a day, ~$3.30 a month**. The pipeline itself is cheap; what costs is people working on it and people looking at it.

**What keeps it cheap, already in place:** XSMALL warehouses with 60 s auto-suspend, declared in Terraform (`modules/warehouse`, a manual change shows up as drift); a separate BI warehouse so the dashboard never slows the pipeline and its cost is visible on its own; the 20-credit resource monitor (notify at 50 / 80 %, suspend at 100 %, suspend immediately at 110 %) and a 5-credit monitor on the dashboard warehouse alone; budgets per team and a showback table that gives every credit to a team ([GOVERNANCE.md](GOVERNANCE.md)); dashboard queries cached 10 minutes; gold tables pre-aggregated per day so the dashboard reads thousands of rows, not the raw lines; a query tag on every job so each credit has an owner; raw files deleted from the bucket after 90 days; the GCP budget alert; everything in one region (no transfer cost).

**What we learned:** the Streamlit app inside Snowflake keeps its warehouse running while someone has it open, up to 15 minutes after the last interaction by default. That is why the dashboard used as much as the whole pipeline in two days. Fixed on 4 Nov: the app now sleeps 5 minutes after the last interaction (`[snowflake.sleep] streamlitSleepTimeoutMinutes = 5`, Snowflake's minimum, added to the app's `config.toml` by `dashboard/deploy_to_snowflake.py`), see [Snowflake docs](https://docs.snowflake.com/en/developer-guide/streamlit/features/sleep-timer).

## 2. Projection: Datathlon at full size

Assumptions (the company in [USE_CASES.md](USE_CASES.md)): 180 stores, 40,000 products, €1.2 bn revenue (75 % stores). These are orders of magnitude for a decision, not a quote.

| Volume per day | Prototype | Datathlon | Factor |
| --- | --- | --- | --- |
| Stock rows (store × product, nightly count) | 240 | 7.2 M | × 30,000 |
| Till lines (≈ €2.5 M a day at ~€25 a line) | ~700 | ~100,000 | × 140 |
| Web orders (≈ €0.8 M a day at ~€60 an order) | ~55 | ~14,000 | × 250 |

| Item | Sizing | Per month |
| --- | --- | --- |
| Pipeline (Snowflake) | dbt models made incremental for stock and sales; SMALL warehouse (2 credits/h), 10–20 min a day | 10–20 credits, **$40–80** |
| Dashboards (Snowflake) | ~40 users (category managers, CFO, supply chain); XSMALL, 5 min sleep timer, active 2–6 h per working day | 45–130 credits, **$170–520** |
| Storage (Snowflake) | ~0.1 TB after a year (compressed), Time Travel 1 day | **~$3** |
| Google Cloud | Cloud Run ~15 min a day, bucket ~20 GB (90-day retention), scheduler; no Cloud SQL (we would read the shop's own replica) | **under $10** |
| **Total** | | **≈ $220–610 a month, ≈ €2.5–7 k a year** |

To compare: stockouts cost Datathlon ~4 % of sales (assumption), about €48 M a year. If UC2 avoids one stockout in a thousand of those, it pays for the platform several times over (€48 k against at most €7 k).

**What would change the bill, in order:** how long the dashboards stay open (sleep timer, one shared BI warehouse, result cache); then the stock models (incremental, clustered by date); real-time is not needed: managers decide weekly, a daily refresh at 06:00 is enough (UC1), and streaming would multiply the pipeline cost for no better decision. Before going live: a load test on one month at full volume, to replace the 10–20 min estimate with a measure.
