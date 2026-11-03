-- Web shop orders, one row per order (adapted from TD 3.1 silver_orders). The source is a clean system (Postgres with
-- constraints), so nothing is quarantined: test orders are kept and flagged, gold leaves them out (UC1 exclusion).
select
    order_id,
    customer_ref,                          -- a code, no personal data (D-032)
    country,
    fulfilment,
    store_id,                              -- click & collect store, null for home delivery
    status,
    is_test,
    order_ts::timestamp_ntz                as ordered_at_utc,
    order_ts::date                         as order_date,
    updated_at::timestamp_ntz              as updated_at_utc,
    _loaded_at
from {{ source('bronze', 'web_orders') }}
