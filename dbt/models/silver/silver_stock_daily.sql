-- Night stock count, one row per day x store x product (UC3). Typed and checked at load (NOT NULL, control files),
-- so silver only adds the product details and the exclusions UC3 needs.
select
    s.snapshot_date || '|' || s.store_id || '|' || s.sku as stock_key,
    s.snapshot_date,
    s.store_id,
    st.country,
    s.sku,
    p.name                                 as product_name,
    st.city                                as store_city,
    p.category,
    p.status = 'discontinued'              as is_discontinued,   -- UC3 exclusion
    s.on_hand,
    s.received,
    s.emergency,
    s.counted_at,
    s._file,
    s._loaded_at
from {{ source('bronze', 'stock_snapshots') }} s
left join {{ ref('products') }} p on p.sku = s.sku
left join {{ ref('stores') }} st on st.store_id = s.store_id
