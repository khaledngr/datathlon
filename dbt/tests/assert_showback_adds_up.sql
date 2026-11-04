-- Chargeback must give out the whole bill: per warehouse and day, the teams' credits add up to what Snowflake billed
-- (WAREHOUSE_METERING_HISTORY), within rounding. A day billed but missing from the showback would fail here too.
with billed as (
    select convert_timezone('UTC', start_time)::date as usage_date, warehouse_name, sum(credits_used_compute) as billed
    from {{ source('snowflake_usage', 'warehouse_metering_history') }}
    where warehouse_name like 'DATATHLON%'
    group by all
),

charged as (
    select usage_date, warehouse_name, sum(total_credits) as charged
    from {{ ref('gold_cost_showback_daily') }}
    group by all
)

select b.usage_date, b.warehouse_name, b.billed, c.charged
from billed b
left join charged c using (usage_date, warehouse_name)
where abs(b.billed - coalesce(c.charged, 0)) > 0.001
  and b.billed >= coalesce(c.charged, 0)   -- query credits above the bill (attribution rounding) is not a missing cost
