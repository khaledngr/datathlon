# sources/ · the simulated company systems

Datathlon is fictional, so its internal systems are simulated on the laptop. They play the **OLTP** source systems of the diagram.

| Folder | System | Build step | Reused from | Use case |
| --- | --- | --- | --- | --- |
| `catalogue/` | Shared product list (30 sports products, €), stores (8, with coordinates for the weather API), holiday calendar FR/BE/ES (`fetch_holidays.py`, OpenHolidays API) | 4 | TD 3.3 seed idea | all |
| `postgres/` | Web shop database (orders, order lines, products) in Docker, port 5433 ✅ | 4 | TD 2, resource pack `04-source-databases` | UC1 web channel |
| `tills/` | Store till feed: one file per store per day (history) or a batch every 5 s (live), bad rows on purpose, files to GCS ✅ | 6 | TD 3.3 `kiosk_sales_generator.py` | UC1 store channel, live incident |
| `stock/` | Warehouse stock export: one CSV per day after the night count | 7 | TD 2 Part A | UC3 |

The two **real** sources (Open-Meteo weather, OpenHolidays holidays) are public APIs: they have no folder here, their loader is in `ingestion/api_pull/`.

Till feed (from the repo root, Google sign-in done):

```bash
.venv/bin/python sources/tills/till_feed.py --history            # 1 Sep -> yesterday
.venv/bin/python sources/tills/till_feed.py --live --batches 12  # live incident demo
```

*`stock/` comes in step 7.*
