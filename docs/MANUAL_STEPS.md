# Manual steps (what is NOT in Terraform, and why)

The teacher's brief asks us to declare the infrastructure as code **and** list what stays manual (resource pack `09-iac/README.md`: "say them, it is expected"). Everything else in Snowflake and Google Cloud is in [terraform/](../terraform/).

| # | Manual step | Who / where | Why it is manual |
| --- | --- | --- | --- |
| 1 | Snowflake account `NVTLKDO-RP44213` (GCP Frankfurt) and its first admin `ROBINCCR` | Robin, sign-up page (D-026) | Terraform needs an account and an admin to connect to: chicken and egg |
| 2 | Users `KHALED` and `RUDY`, their passwords and MFA | Admin runs [snowflake/setup/00_team_users.sql](../snowflake/setup/00_team_users.sql); each person sets their own password and MFA | Passwords must never be in code or in the state file (D-027) |
| 3 | Key pair per person for Terraform and scripts | Each person: [snowflake/setup/gen_key.py](../snowflake/setup/gen_key.py), then the printed `ALTER USER ... SET RSA_PUBLIC_KEY` | The private key stays on the person's laptop, outside the repo |
| 4 | Email verification for cost alerts | Each person in Snowsight (Settings → Profile) | Snowflake refuses to email unverified addresses |
| 5 | Resource monitor first created and attached to the account (`ALTER ACCOUNT SET RESOURCE_MONITOR`) | [snowflake/setup/01_resource_monitor.sql](../snowflake/setup/01_resource_monitor.sql) (step 2) | Made before Terraform existed; Terraform now **imports** and manages the monitor itself; the account-level attachment stays a one-time SQL line |
| 6 | Google Cloud project `datathlon-513514`, billing account, free trial | Robin, Google Cloud console | Owner and payment details belong to a person, not to code |
| 7 | IAM roles for Khaled (Editor + Project IAM Admin) and Rudy (Editor); Owner moved to Robin's school account `rcacarie@albertschool.com` on 4 Nov (D-044) | Robin, [gcp/setup/00_team_access.md](../gcp/setup/00_team_access.md) | Terraform runs *with* these rights, so they must exist first |
| 8 | Budget alert `datathlon-cost-guard` (€10/month) | Robin's billing console (D-029) | Lives on Robin's billing account, which Terraform cannot reach |
| 9 | Terraform state bucket `datathlon-tfstate-513514` (versioned, private) | `gcloud storage buckets create` (D-031) | Terraform cannot store its state in a bucket it has not created yet |
| 10 | Google sign-in for Terraform | Each person: `gcloud auth application-default login` | Personal credentials, never in the repo |
| 11 | GitHub repo, collaborators, protection of `main` | Khaled on GitHub (D-027) | Repository settings, set once |
| 12 | GitHub Actions secrets (for `terraform plan` on pull requests) Only if GitHub Actions is built (not yet): GitHub → Settings → Secrets | Secrets are typed in GitHub, never committed |
| 13 | Tasks, procedures and the dbt project in schema `OPS` (step 10) | `dbt/deploy_to_snowflake.py`, then [snowflake/tasks/01_daily_pipeline.sql](../snowflake/tasks/01_daily_pipeline.sql) | Pipeline code, versioned in Git and redeployed with each change; Terraform owns the schema and the rights (`EXECUTE TASK`, e-mail integration) |
| 13b | The dashboard app inside Snowflake, schema `APPS` (step 11, D-046) | `dashboard/deploy_to_snowflake.py` | App code, versioned in Git and redeployed with each change; Terraform owns the schema and the analyst's rights |
| 14 | Failure e-mail recipients `OPS.ALERT_RECIPIENTS` | One `INSERT ... SELECT email FROM SNOWFLAKE.ACCOUNT_USAGE.USERS` in Snowflake | E-mail addresses are personal data: not in Git |
| 15 | Snowflake private key of the Cloud Run job, in Secret Manager `datathlon-pipeline-snowflake-key` (public half in `terraform/keys/datathlon_pipeline_cloud.pub`) | Robin, once: `gcloud secrets versions add datathlon-pipeline-snowflake-key --data-file=<key.p8>`, then delete the local file (D-044) | A private key must never be in Git nor in the Terraform state; Terraform owns the empty secret and who may read it |
| 16 | First fill of the Cloud SQL web shop database | `gcloud run jobs execute datathlon-morning-job --region europe-west3 --args=--init-db --wait` ([orchestration/README.md](../orchestration/README.md)) | Data, not infrastructure; done once, refused on a database that already has orders |
