-- The real holidays loaded from the API (step 7b) must be the calendar the fake sales were shaped on (D-033),
-- otherwise the dashboard's holiday effect would not line up. warn: the API may publish a change one day.
{{ config(severity='warn') }}
(select country, holiday_type, start_date, end_date, share from {{ ref('silver_holidays') }}
 minus
 select country, type, start_date, end_date, share from {{ ref('holidays') }})
union all
(select country, type, start_date, end_date, share from {{ ref('holidays') }}
 minus
 select country, holiday_type, start_date, end_date, share from {{ ref('silver_holidays') }})
