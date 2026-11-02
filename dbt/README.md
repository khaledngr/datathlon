# dbt/ · transformations, tests, seed, docs

The dbt project (`datathlon_dbt/`) will hold:

| Layer | Models | Build step |
| --- | --- | --- |
| seed | `products.csv`, the product catalogue (the required seed) | 8 |
| silver | cleaned, typed, deduplicated orders, till sales, stock, weather, holidays | 8 |
| quarantine | bad rows with the reason (duplicate, unknown product, 2099 date…) | 8 |
| gold | `sales_daily_by_channel` (UC1), `stock_cover_daily` (UC3), `data_quality_daily` | 9 |
| tests | keys, business rules, freshness, "every raw row is in silver or quarantine", gold = silver | 8, 9 |

Reused from: TD 3.1/3.2 `redgrave_dbt`, TD 3.3 `redgrave_kiosk_dbt`, resource pack `03-cleaning-examples/dbt`.
The TD project already ran as **dbt Projects on Snowflake** (inside Snowflake, no local credentials); we plan the same (decision D-022 point 2, to confirm).

*Empty for now: filled in steps 8 and 9.*
