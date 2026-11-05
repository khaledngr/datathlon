-- Weather per store and day for the managers: the measured past next to that store's till sales, and the next 7 days
-- of forecast (Open-Meteo, a real API) to prepare the week (UC1 promotions, UC2 restocking). Context, like the holidays:
-- our till generator does not use the weather, so we show it next to the sales, we do not claim an effect (D-021).
-- Grain: store x day, from the first complete day to the end of the forecast. Sales: complete days only (D-040).
with store_sales as (
    select store_id, sale_date, sum(qty) as units, sum(revenue_eur) as revenue_eur
    from {{ ref('silver_till_sales') }}
    where sale_date between {{ first_complete_day() }} and {{ last_complete_day() }}
    group by all
)

select
    w.weather_key,
    w.store_id,
    st.city                                     as store_city,
    st.country,
    w.weather_date,
    w.is_forecast,
    w.temp_max_c,
    w.temp_min_c,
    w.rain_mm,
    w.wind_max_kmh,
    case when w.rain_mm >= 2 then 'rainy'                    -- 2 mm: the usual "rainy day" threshold
         when w.temp_max_c >= 25 then 'hot'
         when w.temp_max_c < 8 then 'cold'
         else 'mild' end                        as weather_label,
    s.units                                     as store_units,
    s.revenue_eur                               as store_revenue_eur
from {{ ref('silver_weather_daily') }} w
join {{ ref('stores') }} st on st.store_id = w.store_id
left join store_sales s on s.store_id = w.store_id and s.sale_date = w.weather_date
where w.weather_date >= {{ first_complete_day() }}
