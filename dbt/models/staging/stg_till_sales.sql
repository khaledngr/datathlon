-- Step 1 · PARSE every raw till line into typed columns, nothing filtered (adapted from TD 3.3 stg_kiosk_sales).
-- Each expression fixes one defect of the feed (comment on the right). Rules are checked in quarantine / silver.
with source as (
    select raw, _file, _file_row, _loaded_at
    from {{ source('bronze', 'till_sales_raw') }}
),

stores as (
    select store_id, upper(replace(name, 'Datathlon ', '')) as short_name from {{ ref('stores') }}
),

parsed as (
    select
        s.raw:sale_id::string                                             as sale_id,

        -- "par-01 ", "PAR01" -> PAR-01; "Paris La Defense" -> PAR-01 (store name without the brand)
        upper(trim(s.raw:store_id::string))                               as store_raw,
        case
            when replace(store_raw, '-', '') rlike '[A-Z]{3}[0-9]{2}'
                then left(replace(store_raw, '-', ''), 3) || '-' || right(replace(store_raw, '-', ''), 2)
            else st.store_id
        end                                                               as store_id,

        s.raw:till::string                                                as till,

        -- 3 formats: ISO, "26/10/2026 15:04" (UTC), epoch milliseconds
        case
            when typeof(s.raw:sold_at) = 'INTEGER'
                then to_timestamp_ntz(try_to_number(s.raw:sold_at::string), 3)
            else coalesce(
                convert_timezone('UTC', try_to_timestamp_tz(s.raw:sold_at::string))::timestamp_ntz,
                try_to_timestamp_ntz(s.raw:sold_at::string, 'DD/MM/YYYY HH24:MI'))
        end                                                               as sold_at_utc,

        nullif(upper(trim(s.raw:sku::string)), '')                        as sku,          -- "dth-run-001" -> upper
        try_to_number(trim(s.raw:qty::string))                            as qty,          -- "two" -> null, "1 " -> 1

        -- schema drift: some tills send unitPrice instead of unit_price
        coalesce(s.raw:unit_price, s.raw:unitPrice)::string               as unit_price_raw,
        -- "€39,99" -> 39.99, "39,99" -> 39.99 (cents are fixed against the catalogue in silver)
        try_to_decimal(replace(replace(unit_price_raw, '€', ''), ',', '.'), 10, 2) as price_number,

        case
            when lower(trim(s.raw:payment::string)) in ('card', 'cash', 'contactless')
                then lower(trim(s.raw:payment::string))
            when lower(trim(s.raw:payment::string)) = 'apple pay' then 'contactless'
            else 'unknown'
        end                                                               as payment,

        -- GDPR: the loyalty card code is pseudonymous personal data: keep only a hash
        sha2(s.raw:loyalty_id::string)                                    as loyalty_hash,
        s.raw:promo_code::string                                          as promo_code,

        -- the day of the file (tills/YYYY/MM/DD/...): a sale far older than its file is a late event
        to_date(split_part(s._file, '/', 2) || split_part(s._file, '/', 3) || split_part(s._file, '/', 4), 'YYYYMMDD') as file_date,
        s._file,
        s._file_row,
        s._loaded_at
    from source s
    left join stores st on st.short_name = upper(trim(s.raw:store_id::string))
)

select * from parsed
