# Use cases

Two use cases (D-013). Each one gives the decision and its user, the metric with its grain, formula and exclusions, the refresh frequency and why, and the acceptance test. The store sales of UC1 come from the till feed, which also carries the live incident (D-014).
All numbers about the company are assumptions.

## The company in numbers (assumptions)

| | Assumption |
| --- | --- |
| Business | Omnichannel sports retailer, ~70 % own brands, stores + website |
| Size | 180 stores (France, Belgium, Spain), 3 warehouses, ~9,000 staff |
| Revenue | ~€1.2 bn per year, 25 % online |
| Customers | 6 M loyalty members, families and amateur athletes |
| Catalogue | ~40,000 products, strongly seasonal |
| Pain points | Stockouts on seasonal items (~4 % of sales lost), end-of-season markdowns (~8 % of revenue), no single view of store + online, Black Friday spikes |

---

## UC1 · Daily omnichannel sales and revenue (core)

| | |
| --- | --- |
| **Decision** | Which categories and channels to push or cut in next week's promotions |
| **User** | Category managers, CFO |
| **Metric** | Paid revenue and units sold. **Grain:** day × channel (store / web) × country × category. **Formula:** `SUM(quantity × unit_price)` over order lines of paid orders. **Exclusions:** cancelled and refunded orders, test orders |
| **Frequency** | Daily at 06:00 for the day before (D-1). Managers decide weekly; real time would cost more without changing the decision |
| **Acceptance test** | Gold revenue = silver revenue (dbt reconciliation test) and matches the source totals extracted from Postgres for the same day |
| **Sources** | Postgres "web orders" database (OLTP): orders, order lines, products. Till feed for the store channel (D-014). Weather and holidays as context (D-021) |
| **Ingestion** | Batch first load + **incremental** watermark and `MERGE` (no duplicates on re-run). Postgres is the web shop's live database: orders arrive all day, but it pushes nothing and triggers nothing. Our job *pulls* the rows changed since the last run (the watermark), once a day before 06:00, then the Snowflake Tasks take over (D-022) |

## UC2 · Stock cover alert

| | |
| --- | --- |
| **Decision** | What to restock, in which store, before it runs out |
| **User** | Supply chain manager |
| **Metric** | **Days of cover** = stock on hand ÷ average daily units sold over the last 7 days. **Grain:** store × product × day. Alert when below 3 days. **Exclusions:** products discontinued, stores closed that day |
| **Frequency** | Daily, after the night inventory count |
| **Acceptance test** | Stock on hand in gold = warehouse snapshot total; no product with sales but no stock row |
| **Sources** | Store stock system (OLTP): daily stock CSV export after the night count, with a control file; plus units sold from UC1 (tills + paid click & collect) |
| **Ingestion** | Daily **batch** (`COPY INTO` of the snapshot file, reconciled against the control file on every run) |

---

## How the two use cases cover the requirements

| Requirement | Covered by |
| --- | --- |
| Several sources | Postgres web orders and store till feed (UC1), store stock export (UC2), weather and holidays APIs (context for both), product and store catalogue as a dbt seed |
| Several ingestion methods | Incremental `MERGE` with a watermark (web orders), micro-batch files every few seconds (tills), daily batch with a control file (stock), API pull (weather, holidays) |
| dbt with tests and a seed | Silver, quarantine and gold models, 70 tests, the catalogue seed |
| A corrupted row shown live | Bad till lines → quarantine with their reason, live ([INCIDENTS.md](INCIDENTS.md)) |
| Incidents without a snowball effect | Broken stock file: load refused, nothing half-loaded, dbt skipped, team e-mailed; a failed task retried twice without double counting |

UC1 is built first; UC2 sits on top of it, since days of cover needs UC1's units sold.
