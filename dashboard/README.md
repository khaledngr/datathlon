# dashboard/ · Streamlit on GOLD (step 11, D-016, D-045)

A Streamlit app that reads **only** the GOLD tables, with the read-only role `DATATHLON_ANALYST` on the warehouse `DATATHLON_BI_WH` (XSMALL, auto-suspend 60 s). Adapted from the resource pack `08-visualisation/streamlit/streamlit_app.py`.

| Tab | The question (= the chart title) | Gold tables |
| --- | --- | --- |
| UC1 · Sales | Which categories and channels should next week's promotions push? Revenue / units toggle (charts and titles follow it); KPIs with the change vs the previous week; **Push** (top 3 rising category × channel) and **Watch** (top 3 falling) boxes; next school holidays per country; revenue per day (store, web) with school holidays shaded; per day in holidays vs other days, per category; last 7 days by category × channel with the change vs the week before | `GOLD_SALES_DAILY`, `GOLD_HOLIDAYS` |
| UC2 · Stock alerts | What should we restock, in which store, before it runs out? Alert threshold slider (default 3 days = the UC2 rule) and store filter; alerts, share of shelves and emergency transfers vs the previous night count (same stores); restock list of a night count (latest first); alerts per night count and category, deliveries as dashed lines | `GOLD_STOCK_COVER_DAILY`, `GOLD_HOLIDAYS` |
| Data quality | Can we trust the store sales figures? Red / green box with the incidents of the period; % quarantined (change vs the previous week), quarantined lines per day by reason, a store × day grid of the share of each day's prices sent in cents (pale: none or the usual stray lines, red: over 10 % = incident), incident list | `GOLD_DATA_QUALITY_DAILY` |

The sidebar shows **This morning** on every tab: alerts of the latest night count (UC2 rule) and any price incident in the latest till file. Click a legend entry on the stacked bars to keep one category, reason or store (shift-click for more).

Rules from the teacher's README: each title is the use case's question; freshness ("data up to …", when gold was built) and source tables shown; queries cached 10 minutes (`st.cache_data(ttl=600)`) so the dashboard does not burn credits.

Three choices to know:
- **Week-on-week deltas** compare the last 7 days of the selected dates with the 7 days before, and only show when the selection holds 14 days: a half-empty week is never compared with a full one. Stock deltas compare with the previous night count *on the same stores* (on Sunday only the Spanish stores count).
- **The threshold slider** computes the cover with the same formula as `is_alert` in gold (`on_hand / (units_sold_7d / 7)`), not from the rounded `days_of_cover` (2.96 shows 3.0 but is an alert): at 3 days the dashboard gives exactly gold's alerts. Other values are a what-if; the sidebar keeps the rule.
- No average basket: a till line is one product, so gold has no store ticket to divide revenue by.

## Run it

```bash
.venv/bin/pip install -r requirements.txt            # streamlit + altair are in it
.venv/bin/python dashboard/check_access.py           # least privilege: GOLD readable, nothing else, no write
.venv/bin/streamlit run dashboard/streamlit_app.py   # from the repo root (theme in .streamlit/config.toml)
```

Opens at http://localhost:8501. Sign-in (`snowflake_session.py`): your own user and key from `.env` (or `DASHBOARD_USER` / `DASHBOARD_PRIVATE_KEY_PATH`), role `DATATHLON_ANALYST`, then `USE SECONDARY ROLES NONE`: our users have `DEFAULT_SECONDARY_ROLES = ALL`, which would add the engineer's rights and hide a missing grant. No `secrets.toml`: the key path comes from `.env` like every other script.

## Inside Snowflake (the web app, D-046)

```bash
.venv/bin/python dashboard/deploy_to_snowflake.py    # files -> stage APPS.DASHBOARD_SOURCE, then CREATE OR REPLACE STREAMLIT
```

The app `DATATHLON.APPS.DATATHLON_DASHBOARD` opens in Snowsight > Projects > Streamlit (the script prints its URL). It is owned by `DATATHLON_ANALYST` and runs with its owner's rights: GOLD only, on `DATATHLON_BI_WH`. Every member has the analyst role. Packages: `environment.yml`, same versions as the laptop. The app sleeps 5 min after the last interaction (sleep timer, added at deploy; default 15) so it does not keep the BI warehouse awake. Redeploy after each change of the app.

## What it shows (data 1 Sep → 3 Nov, checked 4 Nov)

- **Sales:** €3,017,326 paid revenue = `SUM(revenue_eur)` of `GOLD_SALES_DAILY` from 1 Sep (3,017,326.05). In school holidays, units per day: hiking +62 %, cycling +38 %, swimming +12 %; team sports and fitness fall (they peak at back to school).
- **Stock:** alerts build up towards Wednesday and Saturday (deliveries Monday and Thursday) and jump in the All Saints holidays: 46 on Sat 24 Oct (21 % of shelves), 0 on 3 Nov after the holidays.
- **Quality:** 4.8 % of 47,241 till lines quarantined; **Lyon, 24 Oct: 205 of 223 prices sent in cents**, fixed by dbt; every other store-day sends 0 to 7.
- Since the live till incident (step 12, D-047), 4 late till lines count on 2 Nov: revenue €3,017,509.98 (+€183.98).
- Gold starts on 1 Sep: the 12 late till events dated 30–31 Aug (`is_late_event`) are left out by `first_complete_day` (Khaled's fix on step 9, D-040).
