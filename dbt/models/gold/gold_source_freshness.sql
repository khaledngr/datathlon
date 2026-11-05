-- Data freshness (dashboard, Data quality tab): when each of the 5 sources last delivered to BRONZE.
-- A view, not a table: it answers "how old is the data" right now, not as of the 06:00 build. The analyst reads it
-- without any right on BRONZE (a view runs with its owner's rights) and sees only load times and row counts.
{% set sources = [
    ('web_orders',      1, 'Web orders',   'Postgres · incremental MERGE'),
    ('till_sales_raw',  2, 'Store tills',  'Files every few seconds · COPY INTO'),
    ('stock_snapshots', 3, 'Stock counts', 'Nightly CSV + control file'),
    ('weather_raw',     4, 'Weather',      'Open-Meteo API'),
    ('holidays_raw',    5, 'Holidays',     'OpenHolidays API'),
] %}
{% for table, position, name, method in sources %}
select
    {{ position }} as position,
    '{{ name }}' as source_name,
    '{{ method }}' as ingestion,
    convert_timezone('UTC', max(_loaded_at))::timestamp_ntz as last_loaded_utc,
    count(*) as rows_in_bronze
from {{ source('bronze', table) }}
{% if not loop.last %}union all{% endif %}
{% endfor %}
