-- UC3 story check (D-033, D-037): in France and Belgium, the share of shelves under 3 days of cover must rise in the
-- All Saints school holidays (measured ~8 %) well above the other days (~2 %). If it does not, the cover formula or
-- the joins are wrong. FAILS (returns a row) if the holiday share is below 5 % or not at least twice the normal share.
with flagged as (
    select
        g.is_alert,
        exists (
            select 1 from {{ ref('silver_holidays') }} h
            where h.country = g.country and h.holiday_type = 'school'
              and h.holiday_name ilike 'All Saints%' and g.snapshot_date between h.start_date and h.end_date
        ) as in_all_saints
    from {{ ref('gold_stock_cover_daily') }} g
    where g.country in ('FR', 'BE')
),

shares as (
    select
        avg(iff(in_all_saints, iff(is_alert, 1, 0), null))     as holiday_share,
        avg(iff(not in_all_saints, iff(is_alert, 1, 0), null)) as normal_share
    from flagged
)

select * from shares
where holiday_share is null or holiday_share < 0.05 or holiday_share < 2 * normal_share
