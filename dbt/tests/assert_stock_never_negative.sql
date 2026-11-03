-- Business rule (UC3): a shelf count is never below zero.
select stock_key, on_hand from {{ ref('silver_stock_daily') }} where on_hand < 0
