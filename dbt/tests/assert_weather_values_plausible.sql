-- Business rule: weather values in a plausible range for Western Europe (catches unit or parsing errors).
{{ config(severity='warn') }}
select weather_key, temp_max_c, temp_min_c, rain_mm
from {{ ref('silver_weather_daily') }}
where temp_max_c not between -30 and 50 or temp_min_c > temp_max_c or rain_mm < 0
