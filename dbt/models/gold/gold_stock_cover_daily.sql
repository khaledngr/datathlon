-- UC3 · Stock cover alert. Grain: day x store x product.
-- Days of cover = night stock count of the day / average daily units sold over the last 7 days (that day included,
-- calendar days, a closed Sunday counts as 0 sales). Alert when below 3 days.
-- Units sold = till units + paid click & collect units picked up in that store (the same sales the stock follows).
-- Exclusions: discontinued products; a store closed that day has no count, so no row.
with units_sold as (
    select store_id, sale_date as sales_date, sku, sum(qty) as units
    from {{ ref('silver_till_sales') }}
    group by all
    union all
    select store_id, order_date, sku, sum(qty)
    from {{ ref('silver_web_order_lines') }}
    where status = 'paid' and not is_test and fulfilment = 'click_collect'
    group by all
),

stock as (
    select *
    from {{ ref('silver_stock_daily') }}
    where not is_discontinued
      and snapshot_date <= {{ last_complete_day() }}
      -- a full 7-day window exists only from the 7th day of data
      and snapshot_date >= dateadd(day, 6, (select min(snapshot_date) from {{ ref('silver_stock_daily') }}))
),

sold_7d as (
    select s.stock_key, coalesce(sum(u.units), 0) as units_sold_7d
    from stock s
    left join units_sold u
        on u.store_id = s.store_id and u.sku = s.sku
       and u.sales_date between dateadd(day, -6, s.snapshot_date) and s.snapshot_date
    group by s.stock_key
)

select
    s.stock_key,
    s.snapshot_date,
    s.store_id,
    s.store_city,
    s.country,
    s.sku,
    s.product_name,
    s.category,
    s.on_hand,
    s.received,
    s.emergency,
    d.units_sold_7d,
    round(d.units_sold_7d / 7, 2)                                           as avg_daily_units_7d,
    round(s.on_hand / nullif(d.units_sold_7d / 7, 0), 1)                    as days_of_cover,  -- null: nothing sold
    coalesce(s.on_hand / nullif(d.units_sold_7d / 7, 0) < 3, false)         as is_alert
from stock s
join sold_7d d using (stock_key)
