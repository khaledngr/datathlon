-- UC3 acceptance test: no product sold in a store without a stock row for that store and product.
select distinct s.store_id, s.sku
from {{ ref('silver_till_sales') }} s
left join {{ ref('silver_stock_daily') }} k on k.store_id = s.store_id and k.sku = s.sku
where k.sku is null
