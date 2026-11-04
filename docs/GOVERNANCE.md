# Governance · tags, masking of personal data, showback and budgets

Who sees what is in [slides/access_map.png](slides/access_map.png) and [OWNERSHIP.md](OWNERSHIP.md); what it costs in [COSTS.md](COSTS.md). This page covers the rules that run inside Snowflake. Everything is declared as code ([terraform/governance.tf](../terraform/governance.tf), dbt) except the budgets ([snowflake/setup/04_budgets.sql](../snowflake/setup/04_budgets.sql)), which Terraform cannot declare yet. Live demo: [snowflake/setup/05_governance_check.sql](../snowflake/setup/05_governance_check.sql).

## 1. Tags on every object

Eight tags in `DATATHLON.GOVERNANCE`, each with a fixed list of values (a typo cannot invent a new team):

| Tag | Values | Set on |
| --- | --- | --- |
| `COST_CENTER` | ingestion, transformation, bi, platform | schemas, warehouses, the service user |
| `OWNER` | khaled, robin, rudy | schemas, warehouses |
| `DATA_LAYER` | bronze, silver, quarantine, gold, ops, apps, governance | schemas |
| `DATA_DOMAIN` | sales, web_orders, stock, context, quality, catalogue, platform, cost | every table and view |
| `SOURCE_SYSTEM` | web_shop_postgres, store_tills, store_stock_export, open_meteo_api, openholidays_api, catalogue_seed, snowflake_metering | every table that comes from a source |
| `CONFIDENTIALITY` | public, internal, confidential | every table and view |
| `ENVIRONMENT` | prod, dev | the database |
| `PII` | direct_identifier, pseudonymised | personal columns: **masked automatically** |

- A table inherits the tags of its schema: `GOLD_SALES_DAILY` is `gold`, owned by `robin`, paid by `transformation` without being tagged itself.
- Terraform tags the database, schemas, warehouses, the service user and the bronze tables. dbt re-creates its tables on every build, which drops their tags, so a post-hook ([dbt/macros/apply_governance_tags.sql](../dbt/macros/apply_governance_tags.sql)) sets domain, source and confidentiality again from `dbt_project.yml`.
- **Query tags:** every query says which team ran it, `datathlon:<team>:<job>` (scripts through `ingestion/sf_connect.py`, each Snowflake task, dbt, the dashboard). That is what the showback reads.

## 2. Personal data: tag-based dynamic masking

Datathlon stores no name, e-mail or address (GDPR by design), but two identifiers still point to a person: the web **customer code** (`BRONZE.WEB_ORDERS.CUSTOMER_REF`) and the **loyalty card number** inside each raw till line (`BRONZE.TILL_SALES_RAW.RAW`). Both carry the tag `PII = direct_identifier`, and the tag carries two masking policies, one per data type:

| Who | Sees |
| --- | --- |
| `DATATHLON_PII_READER` as primary role (Robin and Khaled, for support or a GDPR request) | the real value |
| Everyone else, the pipeline included | its SHA-256: the same person always gets the same pseudonym, so counts and joins still work |
| `DATATHLON_ANALYST` | nothing: it cannot reach BRONZE or SILVER at all |

- **Masked at rest for the pipeline:** dbt runs as the engineer role, so it only ever reads pseudonyms, and silver stores pseudonyms. Encryption at rest and in transit is Snowflake's (AES-256, TLS).
- **Why the primary role only (`CURRENT_ROLE`):** our users have every role active at once by default; an admin running dbt would otherwise write clear values into silver.
- **Only admins decide what is personal:** engineers may apply every tag except `PII`, so they cannot unmask a column by removing its tag. Any new column tagged `PII` is masked with no other change.

## 3. Showback and chargeback

`GOLD.GOLD_COST_SHOWBACK_DAILY` (dbt, rebuilt every morning) gives every credit of our two warehouses to a team, per day:

1. Each query goes to a team by its query tag (`QUERY_ATTRIBUTION_HISTORY`); the dashboard warehouse is `bi`; anything untagged is `platform` (shared).
2. Warehouse time with no query running (start-up, the 60 s before auto-suspend) is billed too: it is shared out between the teams in proportion to their query credits (**chargeback**), so the total equals the bill. Test `assert_showback_adds_up` checks it on every build.

First result (2 → 4 Nov, 5.03 credits, equal to `WAREHOUSE_METERING_HISTORY` to the thousandth):

| Team | Owner | Credits | $ |
| --- | --- | --- | --- |
| BI (dashboard) | Rudy | 2.62 | 10.21 |
| Transformation | Robin | 1.03 | 4.02 |
| Platform (shared, mostly before query tags existed) | Khaled | 1.00 | 3.90 |
| Ingestion | Khaled | 0.38 | 1.50 |

**Showback** = each team sees its line. **Chargeback** = the same lines billed to each team's budget: at Datathlon, the dashboard line would go to the category managers' and supply chain's budgets.

## 4. Budgets and caps

| | Stops the warehouse | Warns before |
| --- | --- | --- |
| Account | resource monitor 20 credits (Terraform) | account budget 20 credits |
| Pipeline `DATATHLON_WH` (ingestion + transformation) | account monitor | budget `BUDGET_PIPELINE` 12 credits |
| Dashboard `DATATHLON_BI_WH` (BI) | resource monitor `DATATHLON_BI_MONITOR` 5 credits (Terraform) | budget `BUDGET_DASHBOARD` 5 credits |
| Google Cloud | — | budget `datathlon-cost-guard` €10 (billing console) |

A resource monitor **stops** compute at the cap. A budget **forecasts** the end of the month and e-mails the team (`OPS.ALERT_RECIPIENTS`) when the forecast goes over the limit. Snowsight > Admin > Cost management > Budgets shows both.

## Set up once (in this order)

```bash
cd terraform && terraform plan && terraform apply   # schema, tags, masking, PII role, grants
```

Then in Snowsight as ACCOUNTADMIN: [04_budgets.sql](../snowflake/setup/04_budgets.sql). Then deploy dbt (the post-hook needs the tags): `.venv/bin/python dbt/deploy_to_snowflake.py`. The query tags of the Cloud Run job change with its next image (`orchestration/push_image.sh`); until then its old tags are still recognised.
