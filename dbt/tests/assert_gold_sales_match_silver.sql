-- Reconciliation (adapted from TD 3.1 assert_gold_matches_silver): gold must not lose or invent revenue or units.
-- Silver totals with the same rules: valid till lines + paid, non-test web lines, complete days only.
-- FAILS (returns a row) if the totals differ.
with gold as (
    select sum(revenue_eur) as revenue_eur, sum(units) as units from {{ ref('gold_sales_daily') }}
),

silver as (
    select sum(revenue_eur) as revenue_eur, sum(qty) as units
    from (
        select revenue_eur, qty from {{ ref('silver_till_sales') }}
        where sale_date <= {{ last_complete_day() }}
        union all
        select revenue_eur, qty from {{ ref('silver_web_order_lines') }}
        where status = 'paid' and not is_test and order_date <= {{ last_complete_day() }}
    )
)

select g.revenue_eur as gold_revenue, s.revenue_eur as silver_revenue, g.units as gold_units, s.units as silver_units
from gold g cross join silver s
where g.revenue_eur <> s.revenue_eur or g.units <> s.units
