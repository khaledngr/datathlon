-- One row per API call x day: Open-Meteo sends arrays (one value per day), FLATTEN turns them into rows.
select
    w.raw:store_id::string                                     as store_id,
    w.raw:run_date::date                                       as run_date,
    w.raw:fetched_at::timestamp_tz                             as fetched_at,
    d.value::date                                              as weather_date,
    w.raw:response:daily:temperature_2m_max[d.index]::float    as temp_max_c,
    w.raw:response:daily:temperature_2m_min[d.index]::float    as temp_min_c,
    w.raw:response:daily:precipitation_sum[d.index]::float     as rain_mm,
    w.raw:response:daily:wind_speed_10m_max[d.index]::float    as wind_max_kmh,
    w._file
from {{ source('bronze', 'weather_raw') }} w,
     lateral flatten(input => w.raw:response:daily:time) d
