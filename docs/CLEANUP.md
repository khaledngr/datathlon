# Cleanup procedure (C7)

How to switch everything off after the defense, so nothing keeps costing money or keeps access open. Run from the repo root, in this order: data first, then Terraform, then what Terraform does not own ([MANUAL_STEPS.md](MANUAL_STEPS.md)).

**Who:** Khaled for Terraform and Snowflake; Robin for what lives on his accounts (billing, GCP project, Snowflake account).

## 1. Stop what runs

```bash
# Snowflake Tasks (step 10), if they exist: suspend the root task in Snowsight so no run starts
#   ALTER TASK <root task> SUSPEND;
# Local web shop database: container and its data volume
docker compose --env-file .env -f sources/postgres/docker-compose.yml down -v
```

## 2. Empty the landing bucket

Terraform refuses to delete a bucket that still holds files (`force_destroy = false`, on purpose).

```bash
gcloud storage rm -r "gs://datathlon-landing-513514/**"
```

## 3. Destroy the Terraform resources

```bash
cd terraform && terraform plan -destroy    # read the list first
terraform destroy
```

This removes: database `DATATHLON` with every schema and table in it, both warehouses, roles `DATATHLON_ENGINEER` / `DATATHLON_ANALYST` and their grants, service user `DATATHLON_PIPELINE`, storage integration, resource monitor, landing bucket and its IAM.

## 4. Remove what Terraform does not own

| What | How | Who |
| --- | --- | --- |
| Terraform state bucket | `gcloud storage rm -r gs://datathlon-tfstate-513514` (after step 3: the state is no longer needed) | Khaled |
| Users `KHALED`, `RUDY` | `DROP USER KHALED; DROP USER RUDY;` as ACCOUNTADMIN | Robin |
| Private keys on laptops | `rm ~/.snowflake/datathlon/*.p8` on every laptop | each person |
| Local data and secrets | `rm -rf data/ .env terraform/terraform.tfvars` | each person |
| Google sign-in tokens | `gcloud auth application-default revoke` | each person |
| Budget `datathlon-cost-guard` | Billing console → Budgets & alerts → delete | Robin |
| GCP project | `gcloud projects delete datathlon-513514` (recoverable for 30 days, billing stops) | Robin |
| Snowflake account | Trial: let it expire, or Snowsight → Admin → Accounts → drop | Robin |
| GitHub repo | Keep it (the jury and school audits use the Git link); remove collaborators only if asked | Khaled |

## 5. Check

- `terraform state list` returns nothing.
- `gcloud storage ls` shows neither `datathlon-landing-513514` nor `datathlon-tfstate-513514`.
- Snowsight → Admin → Cost management: no credits used after the cleanup date.
- GCP Billing → Reports: no cost after the cleanup date.
