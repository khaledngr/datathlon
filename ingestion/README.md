# ingestion/ · Python jobs that bring data in

| Folder | Method | Source → target | Build step | Reused from |
| --- | --- | --- | --- | --- |
| `incremental_orders/` | Incremental: watermark + `MERGE`, re-runs never duplicate | Postgres → Snowflake BRONZE | 5 | TD 2 `incremental_orders.py` |
| `api_pull/` | API pull: timeout, retry, fail loudly | Open-Meteo + data.gouv.fr → GCS → BRONZE | 7b | resource pack `05_api_to_snowflake.py` |

The two file-based methods (till micro-batch, stock daily batch) are loaded by `COPY INTO` from GCS, so their SQL lives in `snowflake/`.

These jobs run in **Docker** (the containerised job required by C3). Who starts them is still open (decision D-022 point 1).

*Empty for now: filled in steps 5 and 7b.*
