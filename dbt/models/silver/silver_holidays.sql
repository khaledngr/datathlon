-- School and public holidays per country, from the latest run, with the same rules as the calendar the sales
-- generators follow (sources/catalogue/fetch_holidays.py, D-033), so real holidays and fake sales line up.
with latest as (
    select *
    from {{ source('bronze', 'holidays_raw') }}
    qualify dense_rank() over (partition by raw:country, raw:kind order by raw:run_date desc, raw:fetched_at desc) = 1
),

periods as (
    select
        h.value:id::string                                     as holiday_id,
        l.raw:country::string                                  as country,
        iff(l.raw:kind::string = 'SchoolHolidays', 'school', 'public') as holiday_type,
        h.value:startDate::date                                as start_date,
        h.value:endDate::date                                  as end_date,
        h.value:name[0]:text::string                           as holiday_name,
        h.value:nationwide::boolean                            as nationwide,
        h.value:subdivisions                                   as subdivisions
    from latest l,
         lateral flatten(input => l.raw:response) h
),

-- France: a school break only for overseas regions does not move mainland sales
overseas_only as (
    select p.holiday_id
    from periods p,
         lateral flatten(input => p.subdivisions) sd
    group by p.holiday_id
    having count_if(sd.value:shortName::string not in ('RU', 'GP', 'MQ', 'GF', 'YT', 'BL', 'MF', 'PM', 'WF', 'PF', 'NC')) = 0
)

select
    country || '|' || holiday_type || '|' || start_date || '|' || end_date as holiday_key,
    country,
    holiday_type,
    start_date,
    end_date,
    holiday_name,
    -- Belgium: French- and Dutch-speaking communities have different autumn breaks, each counts for half
    iff(country = 'BE' and holiday_type = 'school' and start_date < '2026-12-01', 0.5, 1.0) as share
from periods p
left join overseas_only o using (holiday_id)
where (holiday_type = 'public' and nationwide)                          -- regional public holidays left out
   or (holiday_type = 'school' and country = 'BE')
   or (holiday_type = 'school' and country = 'FR' and o.holiday_id is null)
qualify row_number() over (partition by holiday_key order by holiday_name) = 1
