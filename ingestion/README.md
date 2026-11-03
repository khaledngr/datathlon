# ingestion/ · Python jobs that bring data in

| Folder | Method | Source → target | Build step | Reused from |
| --- | --- | --- | --- | --- |
| `incremental_orders/` ✅ | Incremental: watermark (5-min look-back) + `MERGE`, re-runs never duplicate | Postgres → `BRONZE.WEB_ORDERS`, `WEB_ORDER_LINES`, log in `LOAD_RUNS` | 5 | TD 2 `incremental_orders.py` |
| `api_pull/` | API pull: timeout, retry, fail loudly | Open-Meteo + data.gouv.fr → GCS → BRONZE | 7b | resource pack `05_api_to_snowflake.py` |

The two file-based methods (till micro-batch, stock daily batch) are loaded by `COPY INTO` from GCS, so their SQL lives in `snowflake/`. `sf_connect.py` is the one Snowflake connection every job uses.

Run (from the repo root, Postgres container up):

```bash
.venv/bin/python ingestion/incremental_orders/load_web_orders.py
```

The jobs run as the service user **`DATATHLON_PIPELINE`** (key pair, role `DATATHLON_ENGINEER`, no secondary roles), not as a person. Today they run from `.venv`; step 10 puts them in **Docker** (the containerised job required by C3). Who starts them every day is still open (D-022 point 1).

*`api_pull/` comes in step 7b (Robin).*
