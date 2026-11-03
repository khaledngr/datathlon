-- Integrity (C6): every raw till line is in silver OR in quarantine, exactly once. Nothing may disappear or double.
-- FAILS (returns a row) if the counts differ.
with counts as (
    select
        (select count(*) from {{ source('bronze', 'till_sales_raw') }})   as raw_rows,
        (select count(*) from {{ ref('silver_till_sales') }})            as silver_rows,
        (select count(*) from {{ ref('quarantine_till_sales') }})        as quarantine_rows
)
select * from counts where raw_rows <> silver_rows + quarantine_rows
