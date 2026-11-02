# Use cases

**Status: Decided (D-013): UC1 + UC3.** UC2 was dropped as a use case; it stays below for history. The live incident demo comes from the till feed, which becomes the store-side input of UC1 (D-014, option A). We need 1 to 3. Each one is written the way the grading matrix asks (C2): the decision and its user, the metric with its grain, formula and exclusions, the refresh frequency and why, and the acceptance test.
All numbers about the company are assumptions, to be stated as such on the slides.

## The company in numbers (assumptions, C1)

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
| **Metric** | Paid revenue and units sold. **Grain:** day × channel (store / web) × category. **Formula:** `SUM(quantity × unit_price)` over order lines of paid orders. **Exclusions:** cancelled and refunded orders, test orders |
| **Frequency** | Daily at 06:00 for the day before (D-1). Managers decide weekly; real time would cost more without changing the decision |
| **Acceptance test** | Gold revenue = silver revenue (dbt reconciliation test) and matches the source totals extracted from Postgres for the same day |
| **Sources** | Postgres "web orders" database (OLTP): orders, order lines, products. Till feed for the store channel (D-014). Weather and holidays as context (D-021) |
| **Ingestion** | Batch first load + **incremental** watermark and `MERGE` (no duplicates on re-run). Postgres is the web shop's live database: orders arrive all day, but it pushes nothing and triggers nothing. Our job *pulls* the rows changed since the last run (the watermark), once a day before 06:00, then the Snowflake Tasks take over (D-022) |
| **Reused from** | TD 2 (`incremental_orders.py`, `COPY INTO` scripts), TD 3.1/3.2 dbt medallion (`gold_daily_sales`, `gold_revenue_by_channel`, `gold_top_products`, `assert_gold_matches_silver`), Snowflake Tasks from the resource pack (D-022) |
| **New work** | Rename to Datathlon, change the sample data from football merch to sports products and channels |

## ~~UC2 · Live store-till sales with quality control~~ (dropped, D-013)

Kept for history. Since option A of D-014 was chosen, its till feed becomes the store-side input of UC1 and its quarantine gives the incident demo.

| | |
| --- | --- |
| **Decision** | During a rush (Black Friday, Saturday afternoon), which stores are selling fast and which tills send bad data |
| **User** | Store operations manager |
| **Metric** | Sales per store per hour and **% of rows quarantined**. **Grain:** store × hour. **Exclusions:** duplicates (same sale id re-sent), future-dated sales, unknown products (sent to quarantine, not counted) |
| **Frequency** | Micro-batch every few minutes. The value is acting during the rush, so a daily batch is too late |
| **Acceptance test** | Every raw row ends up either in silver or in quarantine (no row lost); prices match the product catalogue seed |
| **Sources** | Till feed: NDJSON events sent every 5 s by the store tills (simulated), product catalogue **seed** (CSV) |
| **Ingestion** | **Micro-batch** files → stage → Snowflake bronze |
| **Reused from** | TD 3.3: `kiosk_sales_generator.py` (defects already built in: duplicates, pence vs "£4.50", 2099 dates, renamed column, unknown products), dbt `stg → silver → quarantine`, seed, tests `assert_kiosk_rows_accounted_for`, `assert_kiosk_prices_match_catalogue`, `gold_kiosk_data_quality` |
| **New work** | Kiosks become store tills, matchday food becomes sports products (prices in €) |
| **Live incident** | Run the generator, show a corrupted row arriving, the test failing and the row landing in quarantine |

## UC3 · Stock cover alert

| | |
| --- | --- |
| **Decision** | What to restock, in which store, before it runs out |
| **User** | Supply chain manager |
| **Metric** | **Days of cover** = stock on hand ÷ average daily units sold over the last 7 days. **Grain:** store × product × day. Alert when below 3 days. **Exclusions:** products discontinued, stores closed that day |
| **Frequency** | Daily, after the night inventory count |
| **Acceptance test** | Stock on hand in gold = warehouse snapshot total; no product with sales but no stock row |
| **Sources** | Warehouse system (MySQL or CSV export, OLTP) daily stock snapshot, plus units sold from UC1 |
| **Ingestion** | Daily **batch** (`COPY INTO` of the snapshot file) |
| **Reused from** | TD 2 Part A (export → stage → `COPY INTO`), dbt patterns from TD 3 |
| **New work** | The stock dataset and the days-of-cover model (not in any TD) |

---

## How UC1 + UC3 fit the rules

| Rule | Covered by (chosen: option A of D-014) | Covered by (option B, not chosen) |
| --- | --- | --- |
| At least 3 sources | Postgres web orders, till feed for store sales (UC1); stock snapshot (UC3); product catalogue seed | Postgres web orders (UC1), stock snapshot (UC3), product catalogue seed (a seed as the 3rd source is weak) |
| Several ingestion methods | Incremental `MERGE` and micro-batch files (UC1), daily `COPY INTO` batch (UC3) | Incremental `MERGE` (UC1), daily `COPY INTO` batch (UC3) |
| dbt with tests and a seed | Both; the seed is the product catalogue | Same |
| Corrupted row shown live | Bad till row → quarantine (UC1, TD 3.3 code) | Bad stock row → quarantine (UC3, new code) |
| Two incident scenarios | Bad till data; Airflow task crash and retry without double counting (TD 4.2) | Bad stock row; same Airflow crash |

## Choice

The group chose **UC1 + UC3** (D-013). Build order: UC1 first (most TD code), then UC3 on top of it, since days of cover needs UC1's units sold.
