-- Data quality of the till feed (adapted from TD 3.3 gold_kiosk_data_quality). Grain: file day x store.
-- Every raw line is counted once: in silver or in quarantine (by reason). A store we cannot recognise is 'UNKNOWN'.
with lines as (
    select
        s.file_date,
        coalesce(s.store_id, 'UNKNOWN')        as store_id,
        q.reject_reason,
        v.sale_id is not null                  as is_silver,
        coalesce(v.price_fixed_from_cents, false) as price_fixed_from_cents
    from {{ ref('stg_till_sales') }} s
    left join {{ ref('quarantine_till_sales') }} q on q._file = s._file and q._file_row = s._file_row
    left join {{ ref('silver_till_sales') }} v on v._file = s._file and v._file_row = s._file_row
    where s.file_date <= {{ last_complete_day() }}
)

select
    file_date || '|' || store_id                                            as quality_key,
    file_date,
    store_id,
    count(*)                                                                as raw_lines,
    count_if(is_silver)                                                     as silver_lines,
    count_if(reject_reason is not null)                                     as quarantine_lines,
    round(100 * quarantine_lines / raw_lines, 1)                            as quarantine_pct,
    count_if(price_fixed_from_cents)                                        as price_fixed_from_cents,
    count_if(reject_reason = 'duplicate')                                   as q_duplicate,
    count_if(reject_reason = 'missing_sale_id')                             as q_missing_sale_id,
    count_if(reject_reason = 'unknown_store')                               as q_unknown_store,
    count_if(reject_reason = 'unparseable_timestamp')                       as q_unparseable_timestamp,
    count_if(reject_reason = 'future_timestamp')                            as q_future_timestamp,
    count_if(reject_reason = 'unknown_product')                             as q_unknown_product,
    count_if(reject_reason = 'invalid_quantity')                            as q_invalid_quantity,
    count_if(reject_reason = 'invalid_price')                               as q_invalid_price,
    count_if(reject_reason = 'price_not_in_catalogue')                      as q_price_not_in_catalogue
from lines
group by file_date, store_id
