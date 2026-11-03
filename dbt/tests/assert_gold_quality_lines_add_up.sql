-- Data quality table (C6): on every row, raw lines = silver lines + quarantined lines, and the reasons add up.
-- FAILS (returns a row) for any file day x store where a line is lost or counted twice.
select *
from {{ ref('gold_data_quality_daily') }}
where raw_lines <> silver_lines + quarantine_lines
   or quarantine_lines <> q_duplicate + q_missing_sale_id + q_unknown_store + q_unparseable_timestamp
                          + q_future_timestamp + q_unknown_product + q_invalid_quantity + q_invalid_price
                          + q_price_not_in_catalogue
