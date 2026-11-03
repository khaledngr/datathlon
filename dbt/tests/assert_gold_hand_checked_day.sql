-- Acceptance test UC1 (C6): one cell checked by hand from BRONZE, line by line (journal #134).
-- Belgium, 24 Oct 2026, Cycling. Store: 22 raw lines in BRU-01's file, 5 rejected ("two", -2, a resent duplicate,
-- 2 without sale id) -> 17 lines, 22 units, 1,462.83 EUR. Web: 2 paid orders (2 x 19.99 + 2 x 14.99) -> 4 units, 69.96.
-- FAILS (returns a row) if gold disagrees with the hand count.
with expected (channel, units, revenue_eur) as (
    select * from values ('store', 22, 1462.83), ('web', 4, 69.96)
)

select e.channel, e.units, g.units as gold_units, e.revenue_eur, g.revenue_eur as gold_revenue
from expected e
left join {{ ref('gold_sales_daily') }} g
    on g.channel = e.channel and g.sales_date = '2026-10-24' and g.country = 'BE' and g.category = 'Cycling'
where g.units is distinct from e.units or g.revenue_eur is distinct from e.revenue_eur
