-- Step 2 · QUARANTINE: till lines we cannot trust, with the first reason found (adapted from TD 3.3).
-- Kept, never deleted, so the store IT team can fix the tills. A resent duplicate is also recorded here, so that
-- every raw line ends up in exactly one place: silver or quarantine (test assert_till_rows_accounted_for).
with checked as (
    select
        s.*,
        p.price_eur                                                        as catalogue_price,
        row_number() over (partition by s.sale_id order by s._loaded_at, s._file, s._file_row) as copy_no,
        case
            when s.sale_id is null                                         then 'missing_sale_id'
            when st.store_id is null                                       then 'unknown_store'
            when s.sold_at_utc is null                                     then 'unparseable_timestamp'
            -- _loaded_at is TIMESTAMP_TZ in the account zone (Los Angeles): compare in UTC, or every sale of the
            -- last 8 hours looks "future" (found by the live incident, step 12)
            when s.sold_at_utc > dateadd(minute, 5, convert_timezone('UTC', s._loaded_at)::timestamp_ntz) then 'future_timestamp'
            when p.sku is null                                             then 'unknown_product'
            when s.qty is null or s.qty not between 1 and 20               then 'invalid_quantity'
            when s.price_number is null                                    then 'invalid_price'
            when abs(s.price_number - p.price_eur) > 0.01
             and abs(s.price_number - p.price_eur * 100) > 1               then 'price_not_in_catalogue'
        end                                                                as rule_reason
    from {{ ref('stg_till_sales') }} s
    left join {{ ref('products') }} p on p.sku = s.sku
    left join {{ ref('stores') }} st on st.store_id = s.store_id
)

select
    coalesce(rule_reason, 'duplicate')                                     as reject_reason,
    sale_id, store_raw, store_id, till, sold_at_utc, sku, qty, unit_price_raw, price_number, catalogue_price,
    payment, file_date, _file, _file_row, _loaded_at
from checked
where rule_reason is not null
   or copy_no > 1                    -- the till retried after a timeout: same sale sent twice, keep the first
