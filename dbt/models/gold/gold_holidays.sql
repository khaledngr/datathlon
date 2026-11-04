-- School and public holidays, copied to GOLD for the dashboard (step 11): the analyst role reads GOLD only, and the
-- charts shade the holiday periods so the sales and stock-alert rises can be read against them.
select
    holiday_key,
    country,
    holiday_type,
    start_date,
    end_date,
    holiday_name,
    share
from {{ ref('silver_holidays') }}
