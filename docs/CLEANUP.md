# Cleanup procedure (C7)

How to switch everything off after the defense, so nothing keeps costing money or keeps access open. Run from the repo root, in this order: data first, then Terraform, then what Terraform does not own ([MANUAL_STEPS.md](MANUAL_STEPS.md)).

**Who:** Khaled for Terraform and Snowflake; Robin for what lives on his accounts (billing, GCP project, Snowflake account).

## 1. Stop what runs

```bash
# Snowflake Tasks (step 10): suspend the root task so no run starts (in Snowsight or run_sql.py)
#   ALTER TASK DATATHLON.OPS.T_START SUSPEND;
# Morning job (step 10): pause the schedule (terraform destroy below removes the job, Cloud SQL and the image registry)
gcloud scheduler jobs pause datathlon-morning-job --location europe-west3
# Old laptop setup (D-041, replaced by Cloud Run in D-042): local image, local web shop database and its data volume
docker image rm datathlon-morning-job:1.0.0
crontab -l | grep -v morning_job.sh | crontab -
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

This removes: database `DATATHLON` with every schema and table in it (incl. `OPS`: tasks, procedures, dbt project), both warehouses, roles `DATATHLON_ENGINEER` / `DATATHLON_ANALYST` and their grants, service user `DATATHLON_PIPELINE`, storage integration, e-mail integration, resource monitor, landing bucket and its IAM; on Google Cloud the morning job (Cloud Scheduler, Cloud Run job, Artifact Registry with its images, both secrets, both service accounts) and the **Cloud SQL database** (the only thing that costs per hour, about €0.40 a day: destroy it right after the defense).

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
