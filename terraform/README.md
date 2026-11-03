# terraform/ · infrastructure as code (step 3, D-031)

One folder, two clouds: one `terraform apply` builds the Snowflake side and the Google side and wires them together.

| File | What it declares | Snowflake role used |
| --- | --- | --- |
| `versions.tf` | Providers pinned (`snowflake ~> 2.22`, `google ~> 6.0`), remote state in `gs://datathlon-tfstate-513514` | — |
| `providers.tf` | 3 Snowflake connections (SYSADMIN, SECURITYADMIN, ACCOUNTADMIN) with a key pair; Google with your own sign-in | — |
| `main.tf` | Database `DATATHLON`, schemas BRONZE / SILVER / QUARANTINE / GOLD + `OPS` (tasks, dbt project, step 10), warehouses `DATATHLON_WH` and `DATATHLON_BI_WH` (module), resource monitor (imported from step 2) | SYSADMIN, ACCOUNTADMIN |
| `roles.tf` | Roles `DATATHLON_ENGINEER` (builds) and `DATATHLON_ANALYST` (reads GOLD only), grants to the 3 members; step 10: `EXECUTE TASK` for the engineer, e-mail integration `DATATHLON_ALERTS_EMAIL` | SECURITYADMIN |
| `storage.tf` | Landing bucket `datathlon-landing-513514` (90-day lifecycle), storage integration `DATATHLON_GCS_INT`, read-only access for Snowflake's Google account | ACCOUNTADMIN, SECURITYADMIN |
| `modules/warehouse/` | One warehouse with our cost rules (XSMALL, auto-suspend 60 s), from the resource pack | — |

## Run it (each member, on their own laptop)

1. Key pair on your Snowflake user: `python snowflake/setup/gen_key.py YOUR_USER`, then run the printed `ALTER USER` in Snowsight
2. Google sign-in for Terraform: `gcloud auth application-default login`
3. `cp terraform.tfvars.example terraform.tfvars` and fill in your user and key path
4. `terraform init` · `terraform plan` (review it) · `terraform apply` · `terraform plan` again must say **No changes**

`*.tfvars`, `*.tfstate` and `.terraform/` are never committed. `.terraform.lock.hcl` is committed: it pins the exact provider versions for the whole team.

## Drift demo (for the defense, about 1 minute)

Drift = someone changes the platform by hand and it no longer matches the code. `terraform plan` catches it.

1. In Snowsight, as SYSADMIN: `ALTER WAREHOUSE DATATHLON_BI_WH SET AUTO_SUSPEND = 3600 WAREHOUSE_SIZE = 'SMALL';` (a "quick fix" that would cost 2x credits and run 1 h after each query)
2. `terraform plan` → `~ auto_suspend = 3600 -> 60`, `~ warehouse_size = "SMALL" -> "XSMALL"`, `Plan: 0 to add, 1 to change`
3. `terraform apply` → back to the code's values
4. `terraform plan` → **No changes**

Tested on 3 Nov 2026 with exactly these steps. What stays manual: [docs/MANUAL_STEPS.md](../docs/MANUAL_STEPS.md).

