# dashboard/ · Streamlit on GOLD (step 11, D-016, D-045)

A Streamlit app that reads **only** the GOLD tables, with the read-only role `DATATHLON_ANALYST` on the warehouse `DATATHLON_BI_WH` (XSMALL, auto-suspend 60 s). Adapted from the resource pack `08-visualisation/streamlit/streamlit_app.py`.

| Tab | The question (= the chart title) | Gold tables |
| --- | --- | --- |
| UC1 · Sales | Which categories and channels should next week's promotions push? Revenue per day (store, web) with school holidays shaded; units per day in holidays vs other days, per category; last 7 days by category × channel | `GOLD_SALES_DAILY`, `GOLD_HOLIDAYS` |
| UC2 · Stock alerts | What should we restock, in which store, before it runs out? Restock list of a night count (latest first); alerts per night count and category | `GOLD_STOCK_COVER_DAILY`, `GOLD_HOLIDAYS` |
| Data quality | Can we trust the store sales figures? % quarantined, quarantined lines per day by reason, prices sent in cents per store, incident list | `GOLD_DATA_QUALITY_DAILY` |

Rules from the teacher's README: each title is the use case's question; freshness ("data up to …", when gold was built) and source tables shown; queries cached 10 minutes (`st.cache_data(ttl=600)`) so the dashboard does not burn credits.

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
