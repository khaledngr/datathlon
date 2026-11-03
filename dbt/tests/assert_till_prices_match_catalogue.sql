-- Business rule: after the cents fix, every till price equals the catalogue price (adapted from TD 3.3).
-- severity warn: reported, does not stop the build (a promotion could one day explain a difference).
{{ config(severity='warn') }}
select s.sale_id, s.store_id, s.sku, s.unit_price_eur, p.price_eur
from {{ ref('silver_till_sales') }} s
join {{ ref('products') }} p on p.sku = s.sku
where s.unit_price_eur <> p.price_eur
