-- Quarantine (C6): a line flagged future_timestamp must really be after its load time, both read in UTC.
-- Guards the time-zone bug found by the live incident (step 12): _loaded_at is in the account zone (Los Angeles),
-- so a plain comparison sent every live sale of the last 8 hours to quarantine. FAILS (returns rows) if one is not.
select sale_id, sold_at_utc, _loaded_at, _file
from {{ ref('quarantine_till_sales') }}
where reject_reason = 'future_timestamp'
  and sold_at_utc <= convert_timezone('UTC', _loaded_at)::timestamp_ntz
