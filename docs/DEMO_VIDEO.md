# Demo video · the pipeline in production, end to end

A silent screen recording (about 7 minutes) of one real run: the sources, the bad lines, how the pipeline handles them, up to the dashboard in Snowflake. No voice: a title card ([demo/video_cards.html](demo/video_cards.html)) before each step says what comes next. The same run works live at the defense.

## Before recording (10 min)

1. **Sign in** to Snowsight and to the Google Cloud console (`rcacarie@albertschool.com`) in the browser you record, and check that both are signed in.
2. **Open these tabs, in this order** (zoom 125 %, bookmarks bar hidden):

| # | Tab | URL |
| --- | --- | --- |
| 1 | Title cards, full screen | `docs/demo/video_cards.html` (open the file in the browser) |
| 2 | Cloud Scheduler | https://console.cloud.google.com/cloudscheduler?project=datathlon-513514 |
| 3 | Cloud Run job, executions | https://console.cloud.google.com/run/jobs/details/europe-west3/datathlon-morning-job/executions?project=datathlon-513514 |
| 4 | Landing bucket, today's till folder | https://console.cloud.google.com/storage/browser/datathlon-landing-513514/tills?project=datathlon-513514 |
| 5 | Snowsight worksheet | new SQL worksheet, paste [snowflake/demo/pipeline_walkthrough.sql](../snowflake/demo/pipeline_walkthrough.sql) |
| 6 | Snowsight task graph | Monitoring > Task History > `T_START`, graph view |
| 7 | dbt docs, lineage | http://localhost:8081 (`dbt/dbt.sh docs generate && dbt/dbt.sh docs serve --port 8081`) |
| 8 | Dashboard | https://app.snowflake.com/nvtlkdo/rp44213/#/streamlit-apps/DATATHLON.APPS.DATATHLON_DASHBOARD |

3. **Terminal** at the repo root, large font, cleared, both commands typed in the history (arrow up):
   `.venv/bin/python sources/tills/till_feed.py --live --batches 12` and `.venv/bin/python snowflake/incidents/02_broken_stock_file.py`.
4. **Notifications off** (Do Not Disturb), other windows closed. Recording: `Cmd + Shift + 5` > record the entire screen.

## Shot list

Each step: show the card (2 to 3 s), then the screen. Time = approximate length of the step.

| Step | Card | Screen and action | What must be visible | Time |
| --- | --- | --- | --- | --- |
| 0 | 0 | Title card | The flow sources → dashboard | 5 s |
| 1 | 1 | **Tab 2**: on `datathlon-morning-job` click **Force run**. **Tab 3**: refresh, open the new execution, **Logs** tab | Schedule `30 5 * * *` Europe/Paris; the log lines `web orders reach …`, `Morning job done: Snowflake tasks take over at 06:00` | 50 s |
| 2 | 2 | **Tab 4**: open `tills/` > today, then `stock/` and `api/` | One folder per source and per day | 20 s |
| 3 | 3 | **Terminal**: run the live feed (1 minute). Halfway, **tab 4**: refresh today's `tills/` folder, open one `live_…` file | New files every 5 s; inside a file, defects such as `"qty": "two"` or `-1`, a store sent as `bcn-01 `, a date in 2099 | 70 s |
| 4 | 4 | **Tab 5**: run blocks 0, 1 and 2 (counts before, the 12 live files in the stage). Run block 3 `EXECUTE TASK`. **Tab 6**: refresh until every task is green (about 1 min). Back to tab 5: the second query of block 3 | `unaccounted = 0` before; the graph T_START → 4 loads and checks → T_DBT_BUILD → T_FINALIZE, all **Succeeded** | 80 s |
| 5 | 5 | **Tab 5**: block 4 | The new lines with `_file`, `_file_row`; the `loyalty_id` is a long hash (masked) | 20 s |
| 6 | 6 | **Tab 5**: block 5, both queries. Click one `line_as_sent` cell to show the raw JSON | Reasons: duplicate, missing_sale_id, unknown_product, future_timestamp (2099), invalid_quantity… with the line as sent | 40 s |
| 7 | 7 | **Tab 5**: block 6, then block 7 | Repaired lines first: a store sent as `bcn-01 ` or `BCN01` stored as `BCN-01`, a date sent as `04/11/2026 11:06` stored in UTC; then `unaccounted = 0` for this run and in total | 40 s |
| 8 | 8 | **Terminal**: run the broken stock file script (30 s) | `Load 1, broken file: FAILED … line 42 … ON_HAND`, retry FAILED, BRONZE unchanged, file removed, load OK | 40 s |
| 9 | 9 | **Tab 5**: block 8 (dbt results of this run). **Tab 7**: lineage graph (bottom right button), click `gold_sales_daily` | Models success, **67 tests pass**; sources → staging → silver / quarantine → gold | 40 s |
| 10 | 10 | **Tab 5**: block 9 | Revenue per day and channel; stock alerts per night (46 on 24 Oct, 0 after the holidays) | 25 s |
| 11 | 11 | **Tab 8**: the dashboard. Sales tab (scroll), **Stock alerts** tab, **Data quality** tab (Lyon 24 Oct, prices in cents) | The answer box on top of each tab; the freshness line | 70 s |
| 12 | 12 | **Tab 5**: blocks 10 and 11 | The run that just finished in `OPS.PIPELINE_RUNS` (succeeded, 0 failed); customer codes as hashes; credits per team | 30 s |
| 13 | 13 | End card | | 5 s |

## Good to know

- **Today's live sales reach gold tomorrow:** gold only shows complete days, so the new lines are in bronze, silver and quarantine at once, and in the dashboard after the next 06:00 run. The Data quality tab already shows past incidents (Lyon, 24 Oct).
- **Step 1 is needed** if you record on a day the 05:30 job has not run today (the web check of step 4 fails without it, by design). It is safe to run twice: nothing is loaded twice.
- **If a task fails in step 4,** the graph shows it red and the team gets an e-mail: that is also a valid demo. Fix, then `EXECUTE TASK DATATHLON.OPS.T_START RETRY LAST;`.
- Each recording adds about 100 live lines (about 1 in 5 quarantined) and a run in `OPS.PIPELINE_RUNS`; it costs about 0.05 credit.
