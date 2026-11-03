-- Weather per store and day. Every daily run re-sends the whole history + 7 days of forecast, so the same day comes
-- several times: keep the latest run (a measured value replaces the forecast made before that day).
select
    store_id || '|' || weather_date        as weather_key,
    store_id,
    weather_date,
    temp_max_c,
    temp_min_c,
    rain_mm,
    wind_max_kmh,
    weather_date >= run_date               as is_forecast,
    run_date,
    _file
from {{ ref('stg_weather_days') }}
qualify row_number() over (partition by store_id, weather_date order by run_date desc, fetched_at desc) = 1
