-- UC1 · Daily omnichannel sales (adapted from TD 3.1 gold_daily_sales + gold_revenue_by_channel).
-- Grain: day x channel (store / web) x country x category. Revenue = SUM(qty x unit_price), in euros.
-- Web: paid orders only, test orders left out; click & collect is a web sale (ordered online). Store: valid till lines.
with store_sales as (
    select sale_date as sales_date, 'store' as channel, country, category, qty, revenue_eur, sale_id::string as ticket_id
    from {{ ref('silver_till_sales') }}
),

web_sales as (
    select order_date, 'web', country, category, qty, revenue_eur, order_id::string
    from {{ ref('silver_web_order_lines') }}
    where status = 'paid' and not is_test
),

sales as (
    select * from store_sales
    union all
    select * from web_sales
)

select
    sales_date || '|' || channel || '|' || country || '|' || category as sales_key,
    sales_date,
    channel,
    country,
    category,
    sum(qty)                               as units,
    sum(revenue_eur)                       as revenue_eur,
    count(distinct ticket_id)              as orders_or_tickets,
    count(*)                               as lines
from sales
where sales_date <= {{ last_complete_day() }}
group by all
