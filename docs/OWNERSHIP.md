# Ownership · who owns which part of the pipeline

Each member owns one part end to end: they built or reviewed it, they run it, they answer questions on it. Everyone can run the whole pipeline (see the README), but each part has one name.

| | Khaled | Robin | Rudy |
| --- | --- | --- | --- |
| **Part** | **Ingestion and platform** | **Transformation and orchestration** | **BI and business** |
| Pipeline stages | Sources → BRONZE | BRONZE → SILVER / QUARANTINE → GOLD, the daily run | GOLD → dashboard → decision |
| Code | [terraform/](../terraform/), [sources/](../sources/), [ingestion/](../ingestion/), [snowflake/setup/](../snowflake/setup/), [snowflake/stages/](../snowflake/stages/) | [dbt/](../dbt/), [snowflake/tasks/](../snowflake/tasks/), [orchestration/](../orchestration/) | [dashboard/](../dashboard/), [USE_CASES.md](USE_CASES.md) |
| What they answer on | Cloud choice, Terraform and drift, the 5 sources and their ingestion methods (incremental `MERGE`, `COPY INTO`, control file), roles and access, secrets | dbt models and the 70 tests, quarantine rules, single source of truth, Tasks vs Airflow, Cloud Run + Scheduler, retries and alerts, costs | The company and its pain points, the two use cases and their metrics, the dashboard, who sees what, how a manager acts on it |
| Live demo | Incident 2: truncated stock file, load refused | Incident 1: bad till data live, quarantine | Dashboard: from the alert to the restock decision |
| Decisions ([DECISIONS.md](DECISIONS.md)) | D-021, D-026, D-027, D-029, D-031 to D-037, D-048 | D-014, D-022, D-039, D-040, D-043, D-044, D-047 | D-013, D-016, D-033, D-045, D-046 |
| Snowflake role used | `DATATHLON_ENGINEER` | `DATATHLON_ENGINEER` | `DATATHLON_ANALYST` (owns and deploys the dashboard app) |

## Data owners and stewards

The **owner** is the business person who decides what the data means and who may see it (company roles, assumptions). The **steward** is the team member who keeps it correct in the pipeline and is alerted when it breaks.

| Data | Owner (business) | Steward (team) |
| --- | --- | --- |
| Web orders (Postgres) | E-commerce manager | Khaled |
| Store till sales | Head of store operations | Khaled (load), Robin (quarantine rules) |
| Store stock counts | Supply chain manager | Khaled |
| Weather, holidays (public APIs) | — (public data) | Khaled |
| Gold sales (UC1) | CFO | Robin |
| Gold stock cover (UC2) | Supply chain manager | Robin |
| Gold store weather (context) | Store managers | Robin |
| Dashboard | Category managers, supply chain | Rudy |

A failed morning run e-mails the whole team; the steward of the failed part fixes it (the e-mail names the failed task).
