-- Called by on-run-end (adapted from TD 3.3): one row per model / test result in GOLD.DBT_RUN_RESULTS.
-- Run evidence for the defense: what ran, when, how long, and which tests failed.
{% macro log_run_results(results) %}
  {% if execute and results | length > 0 %}
    {% set table = target.database ~ '.GOLD.DBT_RUN_RESULTS' %}
    {% do run_query('create table if not exists ' ~ table ~ ' (
        invocation_id varchar, run_at timestamp_tz, command varchar, target_user varchar,
        node varchar, resource_type varchar, status varchar,
        failures number, execution_seconds number(10,2))') %}
    {% set rows = [] %}
    {% for r in results %}
      {% do rows.append("('" ~ invocation_id ~ "', current_timestamp(), '" ~ flags.WHICH ~ "', current_user(), '"
          ~ r.node.unique_id ~ "', '" ~ r.node.resource_type ~ "', '" ~ r.status ~ "', "
          ~ (r.failures if r.failures is not none else 'null') ~ ", " ~ (r.execution_time | round(2)) ~ ")") %}
    {% endfor %}
    {% do run_query('insert into ' ~ table ~ ' values ' ~ rows | join(', ')) %}
  {% endif %}
{% endmacro %}
