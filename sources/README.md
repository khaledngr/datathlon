# sources/ · the simulated company systems

Datathlon is fictional, so its internal systems are simulated on the laptop. They play the **OLTP** source systems of the diagram.

| Folder | System | Build step | Reused from | Use case |
| --- | --- | --- | --- | --- |
| `postgres/` | Web shop database (orders, order lines, products) in Docker | 4 | TD 2, resource pack `04-source-databases` | UC1 web channel |
| `tills/` | Store till feed: a JSON file every 5 s, with bad rows on purpose | 6 | TD 3.3 `kiosk_sales_generator.py` | UC1 store channel, live incident |
| `stock/` | Warehouse stock export: one CSV per day after the night count | 7 | TD 2 Part A | UC3 |

The two **real** sources (Open-Meteo weather, data.gouv.fr holidays) are public APIs: they have no folder here, their loader is in `ingestion/api_pull/`.

*Empty for now: filled in steps 4, 6 and 7.*
