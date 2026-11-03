-- Step 3 · SILVER: valid till lines only, one row per sale (adapted from TD 3.3 silver_kiosk_sales).
-- Prices in cents (the Lyon incident of 24 Oct, and single lines) are converted back to euros and flagged.
select
    s.sale_id,
    s.store_id,
    st.country,
    s.till,
    s.sold_at_utc,
    s.sold_at_utc::date                                                    as sale_date,
    s.sold_at_utc::date < dateadd(day, -1, s.file_date)                    as is_late_event,
    s.sku,
    p.category,
    s.qty,
    iff(abs(s.price_number - p.price_eur) > 0.01, s.price_number / 100, s.price_number) as unit_price_eur,
    abs(s.price_number - p.price_eur) > 0.01                               as price_fixed_from_cents,
    s.qty * unit_price_eur                                                 as revenue_eur,
    s.payment,
    s.loyalty_hash,
    s.promo_code,
    s._file,
    s._file_row,
    s._loaded_at
from {{ ref('stg_till_sales') }} s
join {{ ref('products') }} p on p.sku = s.sku
join {{ ref('stores') }} st on st.store_id = s.store_id
where not exists (
    select 1 from {{ ref('quarantine_till_sales') }} q
    where q._file = s._file and q._file_row = s._file_row
)
