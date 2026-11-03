-- Web order lines with the order and product details (adapted from TD 3.1 silver_order_lines).
select
    l.order_id,
    l.line_no,
    o.order_date,
    o.country,
    o.fulfilment,
    o.store_id,
    o.status,
    o.is_test,
    l.sku,
    p.category,
    l.qty,
    l.unit_price_eur,
    l.qty * l.unit_price_eur               as revenue_eur
from {{ source('bronze', 'web_order_lines') }} l
join {{ ref('silver_web_orders') }} o on o.order_id = l.order_id
left join {{ ref('products') }} p on p.sku = l.sku   -- left join: an unknown SKU stays visible and fails a test
