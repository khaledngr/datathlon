# terraform/ · infrastructure as code (step 3, D-031)

One folder, two clouds: one `terraform apply` builds the Snowflake side and the Google side and wires them together.

| File | What it declares | Snowflake role used |
| --- | --- | --- |
| `versions.tf` | Providers pinned (`snowflake ~> 2.22`, `google ~> 6.0`), remote state in `gs://datathlon-tfstate-513514` | — |
| `providers.tf` | 3 Snowflake connections (SYSADMIN, SECURITYADMIN, ACCOUNTADMIN) with a key pair; Google with your own sign-in | — |
| `main.tf` | Database `DATATHLON`, schemas BRONZE / SILVER / QUARANTINE / GOLD, warehouses `DATATHLON_WH` and `DATATHLON_BI_WH` (module), resource monitor (imported from step 2) | SYSADMIN, ACCOUNTADMIN |
| `roles.tf` | Roles `DATATHLON_ENGINEER` (builds) and `DATATHLON_ANALYST` (reads GOLD only), grants to the 3 members | SECURITYADMIN |
| `storage.tf` | Landing bucket `datathlon-landing-513514` (90-day lifecycle), storage integration `DATATHLON_GCS_INT`, read-only access for Snowflake's Google account | ACCOUNTADMIN, SECURITYADMIN |
| `modules/warehouse/` | One warehouse with our cost rules (XSMALL, auto-suspend 60 s), from the resource pack | — |

## Run it (each member, on their own laptop)

1. Key pair on your Snowflake user: `python snowflake/setup/gen_key.py YOUR_USER`, then run the printed `ALTER USER` in Snowsight
2. Google sign-in for Terraform: `gcloud auth application-default login`
3. `cp terraform.tfvars.example terraform.tfvars` and fill in your user and key path
4. `terraform init` · `terraform plan` (review it) · `terraform apply` · `terraform plan` again must say **No changes**

`*.tfvars`, `*.tfstate` and `.terraform/` are never committed. `.terraform.lock.hcl` is committed: it pins the exact provider versions for the whole team.
