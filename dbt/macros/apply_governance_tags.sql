-- Governance tags (docs/GOVERNANCE.md) on every table and view dbt builds. dbt re-creates its tables on each build,
-- which drops their tags: this post-hook sets them again, from the model's meta in dbt_project.yml.
-- Layer, owner and cost center come from the schema (Terraform tags, inherited); here only what differs per table.
{% macro apply_governance_tags() %}
    {%- if not execute -%}{{ return('') }}{%- endif -%}  {#- at parse time config.get() returns a string -#}
    {%- set tag_for = {'data_domain': 'DATA_DOMAIN', 'source_system': 'SOURCE_SYSTEM', 'confidentiality': 'CONFIDENTIALITY'} -%}
    {%- set meta = config.get('meta', {}) -%}
    {%- set tags = [] -%}
    {%- for key, tag in tag_for.items() if meta.get(key) -%}
        {%- do tags.append("DATATHLON.GOVERNANCE." ~ tag ~ " = '" ~ meta[key] ~ "'") -%}
    {%- endfor -%}
    {%- if tags -%}
        alter {{ 'view' if config.get('materialized') == 'view' else 'table' }} {{ this }} set tag {{ tags | join(', ') }}
    {%- else -%}
        select 'no governance tag for {{ this }}'
    {%- endif -%}
{% endmacro %}
