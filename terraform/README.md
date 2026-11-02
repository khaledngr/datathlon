# terraform/ · infrastructure as code

| What | Provider | Build step |
| --- | --- | --- |
| Snowflake resource monitor (alert 80 %, stop 100 %) | Snowflake | 2 |
| Database `DATATHLON`, schemas BRONZE / SILVER / QUARANTINE / GOLD, warehouses, roles `DATATHLON_ENGINEER`, `DATATHLON_ANALYST`, grants | Snowflake | 3 |
| GCS landing bucket in `europe-west3`, access for Snowflake's service account | Google | 3 |
| Remote state in a GCS bucket (`backend "gcs"`) | Google | 3 |

Reused from: TD 4.2 `redgrave-platform/terraform` (warehouse module, roles, `backend.tf.example`), resource pack `09-iac/snowflake` and `09-iac/gcp`.

`*.tfvars`, `*.tfstate` and `.terraform/` are never committed; `terraform.tfvars.example` shows what to fill in.

*Empty for now: filled in steps 2 and 3.*
