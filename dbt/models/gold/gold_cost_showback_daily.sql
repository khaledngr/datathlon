-- Showback / chargeback (docs/GOVERNANCE.md): every Snowflake credit of our warehouses, per day and per team.
-- 1. Each query goes to a team by its query tag: datathlon:<team>:<job> (sf_connect.py, tasks, dbt profile), older tags
--    by their job name, the dashboard by its warehouse. Anything else goes to the shared platform.
-- 2. Warehouse time not used by any query (start-up, the 60 s before auto-suspend) is billed too: it is shared out
--    between the teams in proportion to their query credits (chargeback), so the total equals the bill.
with queries as (
    select
        convert_timezone('UTC', start_time)::date as usage_date,
        warehouse_name,
        coalesce(query_tag, '') as query_tag,
        credits_attributed_compute as credits
    from {{ source('snowflake_usage', 'query_attribution_history') }}
    where warehouse_name like 'DATATHLON%'
),

by_team as (
    select
        usage_date,
        warehouse_name,
        case
            when warehouse_name = 'DATATHLON_BI_WH' or query_tag ilike 'datathlon:bi:%'
                 or query_tag ilike 'datathlon:dashboard%' or query_tag ilike '%streamlit%' then 'bi'
            when query_tag ilike 'datathlon:transformation:%' or query_tag ilike 'datathlon:dbt%'
                 or query_tag ilike 'datathlon:deploy:dbt%' then 'transformation'
            when query_tag ilike 'datathlon:ingestion:%' or query_tag ilike 'datathlon:step5:%'
                 or query_tag ilike 'datathlon:sql:0%' or query_tag ilike 'datathlon:incident:stock%'
                 or query_tag ilike 'datathlon:morning_job%' then 'ingestion'
            else 'platform'
        end as cost_center,
        sum(credits) as query_credits
    from queries
    group by all
),

metered as (
    select
        convert_timezone('UTC', start_time)::date as usage_date,
        warehouse_name,
        sum(credits_used_compute) as billed_credits
    from {{ source('snowflake_usage', 'warehouse_metering_history') }}
    where warehouse_name like 'DATATHLON%'
    group by all
),

-- a warehouse-day billed without any attributed query: all of it is idle, charged to the platform
teams as (
    select * from by_team
    union all
    select m.usage_date, m.warehouse_name, 'platform', 0
    from metered m
    where not exists (select 1 from by_team t where t.usage_date = m.usage_date and t.warehouse_name = m.warehouse_name)
),

allocated as (
    select
        t.usage_date,
        t.warehouse_name,
        t.cost_center,
        t.query_credits,
        greatest(m.billed_credits - sum(t.query_credits) over (partition by t.usage_date, t.warehouse_name), 0)
            * case when sum(t.query_credits) over (partition by t.usage_date, t.warehouse_name) > 0
                   then t.query_credits / sum(t.query_credits) over (partition by t.usage_date, t.warehouse_name)
                   else 1 / count(*) over (partition by t.usage_date, t.warehouse_name) end as idle_credits
    from teams t
    join metered m on m.usage_date = t.usage_date and m.warehouse_name = t.warehouse_name
)

select
    usage_date || '|' || warehouse_name || '|' || cost_center as showback_key,
    usage_date,
    warehouse_name,
    cost_center,
    case cost_center when 'ingestion' then 'khaled' when 'transformation' then 'robin' when 'bi' then 'rudy'
                     else 'khaled' end as owner,
    round(query_credits, 6) as query_credits,
    round(idle_credits, 6) as idle_credits,
    round(query_credits + idle_credits, 6) as total_credits,
    round((query_credits + idle_credits) * {{ var('credit_price_usd') }}, 4) as total_usd
from allocated
