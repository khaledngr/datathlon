-- Gold shows complete days only (D-040): the last day that EVERY source has reached (web orders, till files, night
-- stock count). A day where one source is late would show web sales without store sales, or sales without stock.
-- Business day = the UTC date: every source stamps UTC (assumption, D-040).
{% macro last_complete_day() %}
    (select least(
        (select max(order_date) from {{ ref('silver_web_orders') }}),
        (select max(file_date) from {{ ref('stg_till_sales') }}),
        (select max(snapshot_date) from {{ ref('silver_stock_daily') }})))
{% endmacro %}

-- The first day EVERY source has: late till events can be dated before the first file (30-31 Aug), which would show
-- days with a handful of store sales and no web sales. Gold starts here.
{% macro first_complete_day() %}
    (select greatest(
        (select min(order_date) from {{ ref('silver_web_orders') }}),
        (select min(file_date) from {{ ref('stg_till_sales') }}),
        (select min(snapshot_date) from {{ ref('silver_stock_daily') }})))
{% endmacro %}
